import logging
import os
from logging.handlers import RotatingFileHandler

def setup_logging(log_file='agent_farm.log', level=logging.DEBUG):
    """
    Sets up logging to both a file and the console.
    """
    # Ensure the log directory exists
    log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, log_file)

    # Create logger
    logger = logging.getLogger('agent_farm_logger')
    logger.setLevel(level)

    # Create formatters
    console_formatter = logging.Formatter('%(name)s - %(levelname)s - %(message)s')
    file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # File handler (rotating)
    file_handler = RotatingFileHandler(
        log_path,
        maxBytes=10*1024*1024, # 10 MB
        backupCount=5
    )
    file_handler.setLevel(level)
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    # Prevent propagation to root logger
    logger.propagate = False

    return logger

# Initialize logger
logger = setup_logging()
