import threading
from typing import List

from instrlib.event import Event
from instrlib.handler_graph import max_element
from instrlib.logger import Logger

import time 

class Instrument:

    def __init__(self, logger : Logger):
        self.logger = logger

    def __call__(self, target):
        if isinstance(target, type):
            self.overwrite_getattribute(self, target)
            self.overwrite_setattribute(self, target)
            return self.instrument_cls(target)
    
    def instrument_cls(self, target):
        qualname = target.__qualname__
        """
        x: to be decorated action, 
        f: function(s) applied onto event args
        """
        def instr(x):
            if callable(x):
                f = self.logger.mp[(qualname,x.__name__)]
                if hasattr(x, '__self__') and x.__self__ is target: # classmethod
                    return self.decorate_classmethod(x, f, target, x.__name__)
                else:
                    return self.decorate_function(x, f, target, x.__name__)
            elif isinstance(x, property):
                return self.decorate_property(x, target,  x.fget.__name__)
            return x
        
        for expr in dir(target):
            if (target.__qualname__, expr) not in self.logger.mp:
                continue
            x = getattr(target, expr)
            if not hasattr(target, '_is_decorated'):
                instrumented_x = instr(x)
            setattr(target, expr, instrumented_x) 
            setattr(target, '_is_decorated', True)
               
        for attr_name, attr_value in target.__dict__.items():
            if isinstance(attr_value, type): #decoration of subclasses
                decorated_cls = Instrument(self.logger)(attr_value)
                setattr(target, attr_name, decorated_cls)
        
        return target
    
    def decorate_classmethod(self, x, f, target, qualname : str):
        def wrapper(*args, **kwargs):
            events = f(*args, **kwargs)
            cau_flag, sup_flag, cau_events, sup_events = self.check_round_trip_time(events, qualname, 1,  target.__qualname__, False, *args, **kwargs)
            if cau_flag:
                return self.invoke_handler(self.logger.mp.cau_graph, cau_events, self.logger.cau_enc, self.logger.mp.cau_event_map, x(*args, **kwargs))
            if sup_flag:
                return self.invoke_handler(self.logger.mp.sup_graph, sup_events, self.logger.sup_enc, self.logger.mp.sup_event_map, x(*args, **kwargs))
            return x(*args, **kwargs)
        return wrapper
    
    def decorate_function(self, x, f, target, qualname : str):
        def wrapper(inst, *args, **kwargs):
            events = f(*args, **kwargs)
            cau_flag, sup_flag, cau_events, sup_events = self.check_round_trip_time(events, qualname, 1,  target.__qualname__, False, *args, **kwargs)
            if cau_flag:
                return self.invoke_handler(self.logger.mp.cau_graph, cau_events, self.logger.cau_enc, self.logger.mp.cau_event_map, x(inst, *args, **kwargs))
            if sup_flag:
                return self.invoke_handler(self.logger.mp.sup_graph, sup_events, self.logger.sup_enc, self.logger.mp.sup_event_map, x(inst, *args, **kwargs))
            return x(inst, *args, **kwargs)
        return wrapper
    
    def decorate_property(self, x, target, qualname : str):
        def getter_wrapper(*args, **kwargs):
            f = self.logger.mp[target.__qualname__, qualname, 'read']
            events = f(*args, **kwargs)
            self.check_round_trip_time(events, qualname, 1,target.__qualname__, False, *args, **kwargs)
            return x.fget(*args, **kwargs)
        def setter_wrapper(*args, **kwargs):
            f = self.logger.mp[target.__qualname__, qualname, 'write']
            events = f(*args, **kwargs)
            self.check_round_trip_time(events, qualname, 1, target.__qualname__, False, *args, **kwargs)
            return x.fset(*args, **kwargs)
        def delete_wrapper(*args, **kwargs):
            f = self.logger.mp[target.__qualname__, qualname, 'delete']
            events = f(*args, **kwargs)
            self.check_round_trip_time(events, qualname, 1, target.__qualname__, False,*args, **kwargs)
            return x.fdel(*args, **kwargs)
        return property(fget=getter_wrapper, fset=setter_wrapper, fdel=delete_wrapper)
   
    def overwrite_getattribute(self, instr : "Instrument", cls):
        def custom_getattribute(self, name):
            if name.startswith('_'):
                return object.__getattribute__(self, name)
            if hasattr(cls, name) and not isinstance(getattr(cls, name), property) and not callable(getattr(cls, name)):
                qualname = cls.__qualname__
                if (qualname, name, 'read') in instr.logger.mapping:
                    # print(f"Custom __getattribute__ called for attribute '{name}'")
                    f = instr.logger.mapping[(qualname, name, 'read')]
                    events = f(qualname, name)
                    instr.check_round_trip_time_attr(instr, events, qualname, name, 1)
            return object.__getattribute__(self, name)
        cls.__getattribute__ = custom_getattribute
              
    def overwrite_setattribute(self, instr : "Instrument", cls):
        def custom_setattribute(self, name, val):
            if name.startswith('_') :
                return object.__setattr__(self, name, val) 
            if hasattr(cls, name) and not isinstance(getattr(cls, name), property) and not callable(getattr(cls, name)):
                qualname = cls.__qualname__
                if (qualname, name, 'write') in instr.logger.mapping:
                    # print(f"Custom __setattribute__ called for attribute '{name}'")
                    f = instr.logger.mapping[(qualname, name, 'write')]
                    events = f(qualname, name)
                    instr.check_round_trip_time_attr(self, events, qualname, name, 1, val)
            return object.__setattr__(self, name, val)              
        cls.__setattr__ = custom_setattribute
    
    def check_round_trip_time(self, events : List[Event], qualname : str, eps : float, cls_name : str, flag_q : bool = False, *args, **kwargs):
        if not events:
            return False, False, None, None
        start = time.time()
        event = threading.Event()
        res = self.logger.log(events, event, flag_q)
        event.wait()
        end = time.time()
        print(f"Calling function {cls_name}.{qualname} took {int((end-start)*1000)} ms" )
        if (end-start > eps):
            print(f"Consider increasing the time unit as the roundtrip time is more than {eps}", flush=True)
        return res
    
    def check_round_trip_time_attr(self, instr : "Instrument", events : List[Event], cls_name : str, attr_name : str, eps : float, val=(), flag_q : bool = False):
        if not events:
            return False, False, None, None
        start = time.time()
        event = threading.Event()
        res = instr.logger.log(events, event, flag_q)
        event.wait()
        end = time.time()
        print(f"Calling attribute {cls_name}.{attr_name} took {int((end-start)*1000)} ms" )
        if (end-start > eps):
            print(f"Consider increasing the time unit as the roundtrip time is more than {eps} s", flush=True)
        return res
    
    def invoke_handler(self, graph, event_names, event_args, mp, orig, *args, **kwargs):
        max = max_element(graph, event_names)
        response = None 
        for el in max:
            response = "" if None else response # for function composition of handlers
            handler = mp.get(el)
            response = handler(orig, event_args, response, *args, **kwargs)
        return response  
    
    """
    queries enforcer's decision and returns true if any reactive or proactive command was returned
    """
    def check_func_top_level(self, events, cls_name, func_name, *args, **kwargs):
        cau_flag, sup_flag, cau_events, sup_events = self.check_round_trip_time(events, cls_name, 1, True, *args, **kwargs)
        return not cau_flag and not sup_flag

        