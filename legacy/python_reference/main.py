from __future__ import annotations

import sys

from timesheet_app.audit_log import get_logger, install_exception_hook, setup_audit_logging, shutdown_audit_logging
from timesheet_app.ui_qt import run_app


def main() -> None:
    setup_audit_logging()
    install_exception_hook()
    logger = get_logger("app")
    logger.info("Aplicação desktop iniciada")

    try:
        sys.exit(run_app())
    except SystemExit:
        raise
    except Exception:
        logger.error("Falha fatal durante a execução da aplicação", exc_info=True)
        raise
    finally:
        shutdown_audit_logging()


if __name__ == "__main__":
    main()
