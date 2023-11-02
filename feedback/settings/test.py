"""
Settings for the Mind Map plugin for testing purposes.
"""
from workbench.settings import *  # pylint: disable=wildcard-import

from django.conf.global_settings import LOGGING

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'feedback',
    'workbench',
]

FEATURES = {
    "ENABLE_FEEDBACK_INSTRUCTOR_VIEW": True,
}

SECRET_KEY = 'fake-key'
