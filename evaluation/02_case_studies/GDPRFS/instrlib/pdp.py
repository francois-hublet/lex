from abc import ABC, abstractmethod
from decimal import Decimal
from queue import Queue, PriorityQueue
from subprocess import Popen, PIPE, STDOUT
from threading import Thread, Event
from time import time, sleep
import datetime
import os
import re
import json
from typing import Any, List, Dict, Set, Tuple, Union

from instrlib.timer import Timer
from instrlib.pep import PEP
from instrlib.handler_graph import max_element
from instrlib.event import TimedTuple

class PDP(ABC):

    def __init__(self, log_file : Union[str, None] = None):
        self.log_file         : str     | None = log_file
        self.ocaml_proc       : Popen   | None = None
        self.timer_thread     : Thread  | None = None
        self.writer_thread    : Thread  | None = None
        self.reader_thread    : Thread  | None = None
        self.pep              : PEP     | None = None
        self.write_prio       : PriorityQueue  = PriorityQueue()
        self.timer            : Timer          = Timer()
        self.termination_flag : Event          = Event()
        self.read_queue       : Queue          = Queue()
        
    @abstractmethod
    def ts_bytes(self, stm : str, tsp : Union[float, None] = None, flag_q : bool = False) -> bytes:
        pass

    @abstractmethod
    def command(self) -> List[str]:
        pass 

    @abstractmethod
    def parse_events(self, input_string : str) -> Dict[str, Set[Tuple[str, ...]]]:
        pass

    @abstractmethod
    def tick(self) -> str:
        pass

    def run_timer_thread(self) -> None:
        timer(self, self.write_prio, 1)

    def run_writer_thread(self) -> None:
        if self.ocaml_proc is not None:
            writer(self, self.log_file)
        else:
            _print("writer", "Failed to start writer thread: no process specified")

    def run_reader_thread(self) -> None:
        if self.ocaml_proc is not None and self.pep is not None:
            reader(self)
        else:
            _print("reader", "Failed to start reader thread: no process or no cau_graph specified")

    """
    start all threads and the enforcer
    """
    def start_threads(self) -> None:
        cmd = self.command()

        print(' '.join(cmd))
        self.ocaml_proc    = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=STDOUT)

        self.timer_thread  = Thread(target=self.run_timer_thread)
        self.writer_thread = Thread(target=self.run_writer_thread)
        self.reader_thread = Thread(target=self.run_reader_thread)

        self.timer_thread.start()
        self.writer_thread.start()
        self.reader_thread.start()
    

class EnfGuard(PDP):

    def __init__(self, exe : str, sig : str, formula : str, *args, **kwargs):
        super(EnfGuard, self).__init__(*args, **kwargs)
        self.exe     : str = exe
        self.sig     : str = sig
        self.formula : str = formula

    def ts_bytes(self, stm : str, tsp : Union[float, None] = None, flag_q : bool = False) -> bytes:
        tsp = tsp if tsp is not None else time() * 1000
        tsp2 = str(int(tsp))
        if stm == '':
            return b'@' + tsp2.encode() + b';\n'
        elif flag_q:
            return b'@' + tsp2.encode() + b' ' + stm.encode() + b'?\n'
        else:
            return b'@' + tsp2.encode() + b' ' + str(stm).encode() + b';\n'
    
    def command(self):
        return [
            self.exe,
            '-sig',     self.sig,
            '-formula', self.formula,
            '-json',
        # Extra enforcer options, e.g. INSTRLIB_EXTRA_ARGS="-fix-since".
        ] + os.environ.get('INSTRLIB_EXTRA_ARGS', '').split()
    
    def parse_events(self, input_string : str) -> Dict[str, Set[Tuple[str, ...]]]:
        event_pattern = r'(\w+)\(((?:[^()"]|"(?:[^"\\]|\\.)*")*)\)' #r'(\w+)\((.*?)\)'
        matches = re.findall(event_pattern, input_string)
        event_args: Dict[str, Set[Tuple[str, ...]]] = {}
        for event_name, args in matches:
            arg_tuple = tuple(arg.strip() for arg in args.split(','))
            if event_name in event_args:
                event_args[event_name].add(arg_tuple)
            else:
                event_args[event_name] = {arg_tuple}
        return event_args
        
    def tick(self) -> str:
        return "tick()"
    

def _print(agent : str, msg : str) -> None:
    colors = {
        "black": "\033[30m",
        "red": "\033[31m",
        "green": "\033[32m",
        "yellow": "\033[33m",
        "blue": "\033[34m",
        "magenta": "\033[35m",
        "cyan": "\033[36m",
        "white": "\033[37m",
        "reset": "\033[0m",
    }
    color = {
        "writer":    "green",
        "reader":    "yellow",
        "timer" :    "blue",
        "proactive": "magenta",
    }.get(agent, "black")
    current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
    agent = agent + (10 - len(agent)) * ' '
    formatted_msg = f"[{current_time}] [{agent}]: {msg}"
    color_code = colors.get(color.lower(), colors["reset"])
    print(f"{color_code}{formatted_msg}{colors['reset']}", flush=True)


"""
writer thread reads events from write_prio and writes statements to enforcer and read_queue
additionally, latency statements are sent to whyenf 
"""
def writer(enforcer : PDP, log_file : Union[str, None]) -> None:
    _print("writer", "Starting")
    while True:
        stm = b''
        event : TimedTuple = enforcer.write_prio.get()
        tsp = event.tsp
        (flag, innerqueue, stm) = event.event_tuple
        if event.expects_response:
            enforcer.read_queue.put(TimedTuple(tsp, (flag, innerqueue, stm)))
        assert enforcer.ocaml_proc is not None
        if enforcer.ocaml_proc.poll() is None:
            try:
                if log_file is not None:
                    with open(log_file, 'a') as log:
                        log.write(stm.decode() + "\n")
                assert enforcer.ocaml_proc.stdin is not None
                enforcer.ocaml_proc.stdin.write(stm)
                enforcer.ocaml_proc.stdin.flush()
                _print("writer", f"Sent to enforcer: {stm.decode()}")
            except Exception as e:
                _print("writer", f"Error: {e}")
    _print("writer", "Terminated")


"""
reader thread matches response of enforcer with statements from read_queue;
used to create a proactive thread or wake up worker thread
"""            
def reader(enforcer : PDP) -> None:
    _print("reader", "Starting")

    def getstm(proc):
        output = proc.stdout.readline()
        while output:
            msg = output.decode()
            try:
                return json.loads(msg)            
            except:
                _print("reader", f"Skipping non-JSON: {msg[:-1]}")
            output = proc.stdout.readline()
        return None

    assert enforcer.ocaml_proc is not None
    while enforcer.ocaml_proc.poll() is None: 
        try:
            assert enforcer.ocaml_proc.stdout is not None
            msg = getstm(enforcer.ocaml_proc)
            if msg is not None:
                _print("reader", f"Received from enforcer: {msg}")
                event = enforcer.read_queue.get()
                (flag, innerqueue, order_msg) = event.event_tuple
                _print("reader", f"Matching request: {order_msg.decode()}")
                small_queue : Queue = Queue()
                small_queue.put(msg)
                innerqueue.put(small_queue)
                if msg.get("proactive", False) and len(msg.get("cause", [])) > 0:
                    handle_proactive_commands(msg, enforcer)
                flag.set()
        except Exception as e:
            _print("reader", f"Error: {e}")
    assert enforcer.ocaml_proc.stdout is not None
    enforcer.ocaml_proc.stdout.close()

    _print("reader", "Terminated")


"""
timer thread providing timestamps to enforcer
"""
def timer(enforcer : PDP, order : PriorityQueue, unit : float = 1):
    _print("timer", "Starting")
    timer = enforcer.timer
    while True:
        with timer.current_time_lock:
            if not timer.first_time:
                timer.current_time += 1
            tsp = timer.current_time
            stm = enforcer.ts_bytes(enforcer.tick(), tsp)
            event = Event()
            _print("timer", f"tick({tsp})")
            order.put(TimedTuple(tsp, (event, Queue(), stm), expects_response = not timer.first_time))
            timer.first_time = False
        sleep(unit)
    _print("timer", "Terminated")


"""Handle proactive commands by spawning a new thread and measure its performance"""
def handle_proactive_commands(msg : str, enforcer : PDP):
    start = time()
    proac_thread = Thread(target=spawn_proactive_thread, args=(msg, enforcer))
    proac_thread.start()
    proac_thread.join()
    end = time()
    _print("proactive", f'Terminated. Time thread spawned: {end - start}, current time {time()}')


"""
newly spawned proactive worker thread used to proactively cause events
"""
def spawn_proactive_thread(msg : Dict[str, Any], enforcer : PDP) -> None:
    _print("proactive", f"Starting newly spawned proactive thread: {msg}")
    for event_json in msg["cause"]:
        name = event_json['name']
        args = event_json['args']
        for arg in args:
            _print("proactive", f'Event to be proactively caused: {name} with arguments {arg}')
    event_names = tuple({event_json['name'] for event_json in msg['cause']})
    assert enforcer.pep is not None
    max = max_element(enforcer.pep.cau_graph, event_names)
    _print("proactive", f'Max element: {max}')
    for h_key in max:
        handler = enforcer.pep.cau_event_map.get(h_key)
        if handler is None:
            _print("proactive", f"Failed to find a handler for {h_key}")
        else:
            handler([event_json for event_json in msg["cause"] if event_json['name'] in h_key])