# TODO: sample comment
import os
from pathlib import Path
import subprocess


@decorator
class Sample(Base):
    def method(self, value):
        self.value = value
        if value == None or value != None:
            print("a string")
        assert isinstance(value, int)
        squares = [x * x for x in range(3)]
        key = lambda item: item.name
        for x in squares:
            pass
        with open("file") as f:
            pass
        try:
            eval("1")
        except:
            raise ValueError("bad")
        subprocess.run(["ls"])
