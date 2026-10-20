"""
Performance-benchmark driver for miniTwitter_gdpr.

Scenarios
---------
  timeline          – GET the home timeline
  post_tweet        – POST a new tweet
  erase_tweet       – DELETE a specific tweet  (via /twit/delete/<uuid>/)
  right_to_info     – GET  /gdpr/request/access/  (Art. 15 access request)
  privacy_notices   – GET  /gdpr/notifications/
  give_consent      – POST /gdpr/consent/  (give consent for statistics)
  revoke_consent    – POST /gdpr/consent/  (revoke consent for statistics)

Each scenario is measured under every combination of:
  u  in {1, 10, 100}       users
  n  in {100, 1000, 10000}  total tweets
  c  in {none, statistics, statistics_ads}  consent level
"""

import os
import signal
import shutil
import sqlite3
import random
from datetime import datetime
from pathlib import Path
from subprocess import Popen, PIPE, STDOUT, run as sp_run
from time import sleep
import uuid

import requests
from lorem_text import lorem
from random import randint
from tools import Task, Subtask

# ── Paths ────────────────────────────────────────────────────────────────
_DRIVER_DIR   = Path(__file__).resolve().parent            # drivers/
_SUITE_DIR    = _DRIVER_DIR.parent                         # privacy_testsuite/
_PROJECT_ROOT = _SUITE_DIR.parent.parent                   # miniTwitter_gdpr/
_SNAPSHOT_DIR = _SUITE_DIR / "db_snapshots"
_BASELINE_ROOT = _SUITE_DIR / "baseline" / "minitwitter_bl"  # stripped copy (no enforcement)

# ── URLs ─────────────────────────────────────────────────────────────────
BASE            = "http://127.0.0.1:8000"
LOGIN_URL       = f"{BASE}/accounts/login/"
TIMELINE_URL    = f"{BASE}/"
POST_TWEET_URL  = f"{BASE}/post/twit/"
DELETE_TWEET_URL = f"{BASE}/twit/delete/"          # + <uuid>/
ACCESS_URL      = f"{BASE}/gdpr/request/access/"
NOTIFICATIONS_URL = f"{BASE}/gdpr/notifications/"
CONSENT_URL     = f"{BASE}/gdpr/consent/"

# ── Constants ────────────────────────────────────────────────────────────
CONFIGS        = [(1, 100), (10, 1000), (100, 10000)]   # (users, tweets)
CONSENT_LEVELS = ["none"]#, "statistics", "statistics_ads"]


# =========================================================================
#  Scenario
# =========================================================================

class Scenario:

    def __init__(self, sc, app_cmd, database, policy, consent, env=None,
                 project_root=None):
        self.sc = sc
        self.app_cmd = app_cmd
        self.database = database          # path to the *live* DB used by Django
        self.policy = policy
        self.consent = consent            # consent level tag
        self.env = env or dict(os.environ)
        self.project_root = project_root or _PROJECT_ROOT
        self.log_filename = None
        self.proc = None
        self.u = None
        self.n = None

    # ── helpers ──────────────────────────────────────────────────────
    def _snapshot_path(self):
        return _SNAPSHOT_DIR / f"db_u{self.u}_n{self.n}_c{self.consent}.sqlite3"

    def _state_snapshot_path(self):
        return _SNAPSHOT_DIR / f"state_u{self.u}_n{self.n}_c{self.consent}.bin"

    def _restore_db(self):
        """Copy the pre-built snapshot (DB + enforcer state) over live files."""
        src = self._snapshot_path()
        assert src.exists(), f"Snapshot not found: {src}"
        shutil.copy2(src, self.database)
        # Restore enforcer state for enforced runs
        state_src = self._state_snapshot_path()
        state_dst = self.project_root / "enfflash.state"
        if state_src.exists():
            shutil.copy2(state_src, state_dst)
        elif state_dst.exists():
            state_dst.unlink()

    def _user_session(self, i):
        session = requests.Session()
        r = session.get(LOGIN_URL)
        csrf = session.cookies.get("csrftoken")
        r = session.post(LOGIN_URL, data={
            "username": f"user{i}",
            "password": "password",
            "csrfmiddlewaretoken": csrf,
        })
        assert r.ok, f"Login failed for user{i}: {r.status_code}"
        return session

    def _random_user_session(self):
        return self._user_session(randint(0, self.u - 1))

    def _pick_random_tweet_id(self):
        """Return a random tweet UUID from the live database."""
        db = sqlite3.connect(self.database)
        ids = [r[0] for r in db.execute(
            "SELECT id FROM twitt_twit ORDER BY RANDOM() LIMIT 1").fetchall()]
        db.close()
        return ids[0] if ids else None

    # ── lifecycle ────────────────────────────────────────────────────
    def initialize(self, config):
        self.u, self.n = config
        pref = f"minitwit.init (sc={self.sc}, u={self.u}, n={self.n}, c={self.consent})"

        with Task(pref, "Restoring database snapshot"):
            self._restore_db()

        log_dir = _SUITE_DIR / "logs" / "multi_runs"
        log_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_filename = str(log_dir / f"{ts}_{self.sc}_{self.consent}_{self.policy}.log")
        self._start_server()

    def _start_server(self):
        pref = f"minitwit.init (sc={self.sc}, u={self.u}, n={self.n})"
        with Task(pref, "Starting Django server"):
            # Kill anything already on port 8000
            sp_run(["fuser", "-k", "8000/tcp"],
                   stdout=PIPE, stderr=PIPE)
            sleep(0.5)
            self._log_fh = open(self.log_filename, "a")
            self.proc = Popen(self.app_cmd, stdin=PIPE,
                              stdout=self._log_fh, stderr=STDOUT, text=True,
                              cwd=str(self.project_root), env=self.env)
            self._wait_for_server_ready(timeout_s=30)

    def _wait_for_server_ready(self, timeout_s=30):
        deadline = datetime.now().timestamp() + timeout_s
        while datetime.now().timestamp() < deadline:
            if not self.is_process_running():
                return
            try:
                r = requests.get(LOGIN_URL, timeout=0.5)
                if r.status_code < 500:
                    return
            except requests.exceptions.RequestException:
                pass
            sleep(0.2)

    def continue_(self):
        """Between repeated measurements – for erase_tweet we must restore."""
        if self.sc == "erase_tweet":
            # The tweet we deleted is gone; restore DB and restart server
            self.proc.kill()
            self.proc.wait()
            self._log_fh.close()
            self._restore_db()
            self._start_server()

    def finalize(self):
        with Task("minitwit.finalize", "Killing Django server"):
            if self.proc:
                self.proc.kill()
                self.proc.wait()
                self.proc = None
            if hasattr(self, '_log_fh') and self._log_fh:
                self._log_fh.close()
                self._log_fh = None
            # Make sure port is freed
            sp_run(["fuser", "-k", "8000/tcp"], stdout=PIPE, stderr=PIPE)
            sleep(0.5)

    def is_process_running(self):
        return self.proc is not None and self.proc.poll() is None

    # ── measurement ──────────────────────────────────────────────────
    def run(self):
        result_base = {"sc": self.sc, "u": self.u, "n": self.n,
                       "c": self.consent}

        if not self.is_process_running():
            print("Django server is not running!")
            return None

        try:
            if self.sc == "timeline":
                return self._run_timeline(result_base)
            elif self.sc == "post_tweet":
                return self._run_post_tweet(result_base)
            elif self.sc == "erase_tweet":
                return self._run_erase_tweet(result_base)
            elif self.sc == "right_to_info":
                return self._run_right_to_info(result_base)
            elif self.sc == "privacy_notices":
                return self._run_privacy_notices(result_base)
            elif self.sc == "give_consent":
                return self._run_give_consent(result_base)
            elif self.sc == "revoke_consent":
                return self._run_revoke_consent(result_base)
        except requests.exceptions.RequestException as e:
            print(f"Request error in {self.sc}: {e}")
            return None

    # ── individual workflows ─────────────────────────────────────────
    def _run_timeline(self, base):
        with Task("run", 'Scenario "timeline"'):
            s = self._random_user_session()
            r = s.get(TIMELINE_URL)
            assert r.ok
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_post_tweet(self, base):
        with Task("run", 'Scenario "post_tweet"'):
            s = self._random_user_session()
            csrf = s.cookies.get("csrftoken")
            txt = lorem.paragraph()[:137] + "..."
            r = s.post(POST_TWEET_URL, data={
                "content": txt,
                "twit_uid": str(uuid.uuid4()),  
                "csrfmiddlewaretoken": csrf,
            }, allow_redirects=False)
            assert r.status_code == 302, f"post_tweet failed: {r.status_code}"
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_erase_tweet(self, base):
        with Task("run", 'Scenario "erase_tweet"'):
            twit_id = self._pick_random_tweet_id()
            if twit_id is None:
                print("No tweets to delete")
                return None
            # Log in as the author of that tweet
            db = sqlite3.connect(self.database)
            author_id = db.execute(
                "SELECT author_id FROM twitt_twit WHERE id=?", (twit_id,)
            ).fetchone()[0]
            username = db.execute(
                "SELECT username FROM twitt_user WHERE id=?", (author_id,)
            ).fetchone()[0]
            db.close()

            s = requests.Session()
            r = s.get(LOGIN_URL)
            csrf = s.cookies.get("csrftoken")
            s.post(LOGIN_URL, data={
                "username": username,
                "password": "password",
                "csrfmiddlewaretoken": csrf,
            })
            csrf = s.cookies.get("csrftoken")
            url = f"{DELETE_TWEET_URL}{twit_id}/"
            r = s.post(url, data={"csrfmiddlewaretoken": csrf},
                       allow_redirects=False)
            assert r.status_code == 302, f"erase_tweet failed: {r.status_code}"
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_right_to_info(self, base):
        with Task("run", 'Scenario "right_to_info"'):
            s = self._random_user_session()
            r = s.get(ACCESS_URL)
            assert r.ok
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_privacy_notices(self, base):
        with Task("run", 'Scenario "privacy_notices"'):
            s = self._random_user_session()
            r = s.get(NOTIFICATIONS_URL)
            assert r.ok
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_give_consent(self, base):
        with Task("run", 'Scenario "give_consent"'):
            s = self._random_user_session()
            csrf = s.cookies.get("csrftoken")
            r = s.post(CONSENT_URL, data={
                "give_consent": "statistics",
                "csrfmiddlewaretoken": csrf,
            }, allow_redirects=False)
            assert r.status_code == 302, f"give_consent failed: {r.status_code}"
            return {**base, "t": r.elapsed.total_seconds()}

    def _run_revoke_consent(self, base):
        with Task("run", 'Scenario "revoke_consent"'):
            s = self._random_user_session()
            csrf = s.cookies.get("csrftoken")
            r = s.post(CONSENT_URL, data={
                "revoke_consent": "statistics",
                "csrfmiddlewaretoken": csrf,
            }, allow_redirects=False)
            assert r.status_code == 302, f"revoke_consent failed: {r.status_code}"
            return {**base, "t": r.elapsed.total_seconds()}


# =========================================================================
#  Application
# =========================================================================

class Application:

    app_cmd  = ["python3", "manage.py", "runserver", "127.0.0.1:8000", "--noreload"]

    # Default enforcer path matching the project Makefile (ENFGUARD ?= ~/Git/whyenf/enfguard)
    enfguard_exe = str(Path.home() / "Git" / "whyenf" / "enfguard")

    def start(self, policy, exe):
        self.policy = policy
        self.is_baseline = (policy == "baseline")
        self._project_root = _BASELINE_ROOT if self.is_baseline else _PROJECT_ROOT
        self.database = str(self._project_root / "db.sqlite3")
        self._base_cmd = list(self.app_cmd)
        self._env = dict(os.environ)
        if not self.is_baseline:
            self._env["INSTRLIB_EXE"] = exe if exe else self.enfguard_exe
        with Task("minitwit.start", "Preparing evaluation"):
            pass   # DB preparation is per-snapshot, handled in Scenario.initialize

    def stop(self):
        with Task("minitwit.stop", "Evaluation finished"):
            pass

    def scenarios(self, policy):
        with Task("minitwit.scenarios", "Building scenario list"):
            cmd = list(self._base_cmd)
            env = dict(self._env)
            if not self.is_baseline and policy and policy != "uninstrumented":
                env["INSTRLIB_FORMULA"] = f"policies/{policy}.mfotl"
                env["INSTRLIB_SIG"] = f"policies/{policy}.sig"

            scenario_names = [
                "timeline",
                "post_tweet",
                #"erase_tweet",
                "right_to_info",
                "privacy_notices",
                "give_consent",
                "revoke_consent",
            ]

            scenarios = []
            for sc_name in scenario_names:
                for consent in CONSENT_LEVELS:
                    scenarios.append(
                        Scenario(sc_name, cmd, self.database, policy, consent,
                                 env, project_root=self._project_root)
                    )
        return scenarios

    def configurations(self):
        with Task("minitwit.configurations", "Building configurations"):
            configs = list(CONFIGS)
        return configs

    def dep_vars(self):
        return ["t"]

    def indep_vars(self):
        return ["sc", "u", "n", "c"]
