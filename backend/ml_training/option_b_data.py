# -*- coding: utf-8 -*-
"""
Option B Regional Phrasings Data.
Re-exported for top-level scripts and language server resolution.
"""
import os
import sys

_EXP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "experiments")
if _EXP_DIR not in sys.path:
    sys.path.insert(0, _EXP_DIR)

try:
    from experiments.option_b_data import OPTION_B_PHRASINGS
except ImportError:
    from option_b_data import OPTION_B_PHRASINGS

__all__ = ["OPTION_B_PHRASINGS"]
