import sys
import os

# Ensure the package root (services/product-service) is on sys.path so that
# `from src.main import ...` works when pytest is invoked from this directory.
sys.path.insert(0, os.path.dirname(__file__))
