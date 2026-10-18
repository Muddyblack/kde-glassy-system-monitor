"""Windows performance counters (PDH): what Task Manager reads, no admin needed.

GPU load and memory for any vendor ("GPU Engine", "GPU Adapter Memory"),
ACPI thermal zones, and per-core clock. Wildcard counters are expanded by PDH
on every collection, so processes and adapters that come and go need no
re-adding here.

A Query owns a PDH handle; `close()` releases it (the sampler calls it on
stop). Nothing is cached per instance name on our side.
"""

import ctypes
import sys
from ctypes import wintypes

PDH_FMT_DOUBLE = 0x00000200
PDH_MORE_DATA = 0x800007D2
ERROR_SUCCESS = 0


class _Value(ctypes.Union):
    _fields_ = [("doubleValue", ctypes.c_double), ("longValue", ctypes.c_long)]


class _FmtValue(ctypes.Structure):
    _fields_ = [("CStatus", wintypes.DWORD), ("value", _Value)]


class _Item(ctypes.Structure):
    _fields_ = [("szName", wintypes.LPWSTR), ("FmtValue", _FmtValue)]


def available() -> bool:
    return sys.platform == "win32"


class Query:
    """A set of wildcard counters read together."""

    def __init__(self) -> None:
        self._pdh = ctypes.windll.pdh
        self._handle = ctypes.c_void_p()
        status = self._pdh.PdhOpenQueryW(None, 0, ctypes.byref(self._handle))
        if status != ERROR_SUCCESS:
            raise OSError(f"PdhOpenQuery failed: {status:#x}")
        self._counters: dict[str, ctypes.c_void_p] = {}
        self._buffer = ctypes.create_string_buffer(1 << 14)

    def add(self, path: str) -> bool:
        """Add a counter by its English path; False if this machine lacks it."""
        counter = ctypes.c_void_p()
        status = self._pdh.PdhAddEnglishCounterW(
            self._handle, path, 0, ctypes.byref(counter)
        )
        if status != ERROR_SUCCESS:
            return False
        self._counters[path] = counter
        return True

    def collect(self) -> bool:
        return self._pdh.PdhCollectQueryData(self._handle) == ERROR_SUCCESS

    def values(self, path: str) -> dict[str, float]:
        """{instance name: value} for a wildcard counter; {} if unreadable.

        Rate counters need two collections before they have a value.
        """
        counter = self._counters.get(path)
        if counter is None:
            return {}
        size = wintypes.DWORD(len(self._buffer))
        count = wintypes.DWORD(0)
        status = self._pdh.PdhGetFormattedCounterArrayW(
            counter,
            PDH_FMT_DOUBLE,
            ctypes.byref(size),
            ctypes.byref(count),
            self._buffer,
        )
        if status == PDH_MORE_DATA and size.value <= (1 << 22):
            # Many processes: grow once, and keep the larger buffer.
            self._buffer = ctypes.create_string_buffer(size.value)
            status = self._pdh.PdhGetFormattedCounterArrayW(
                counter,
                PDH_FMT_DOUBLE,
                ctypes.byref(size),
                ctypes.byref(count),
                self._buffer,
            )
        if status != ERROR_SUCCESS:
            return {}
        items = ctypes.cast(self._buffer, ctypes.POINTER(_Item))
        out: dict[str, float] = {}
        for index in range(count.value):
            item = items[index]
            if item.FmtValue.CStatus in (0, 1):  # valid data / new data
                out[item.szName] = item.FmtValue.value.doubleValue
        return out

    def close(self) -> None:
        if self._handle:
            self._pdh.PdhCloseQuery(self._handle)
            self._handle = ctypes.c_void_p()
        self._counters.clear()
