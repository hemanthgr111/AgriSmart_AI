"""Minimal structured logging configuration.

Logs are emitted as JSON-ish single lines. Never log secrets, tokens,
passwords, or OTP values.
"""

import logging
import sys

_CONFIGURED = False


def configure_logging(debug: bool = False) -> None:
    global _CONFIGURED
    if _CONFIGURED:
        return

    level = logging.DEBUG if debug else logging.INFO

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            fmt='%(asctime)s level=%(levelname)s logger=%(name)s msg="%(message)s"',
            datefmt="%Y-%m-%dT%H:%M:%S%z",
        )
    )

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)

    # Reduce noise from chatty third-party loggers.
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

    _CONFIGURED = True
