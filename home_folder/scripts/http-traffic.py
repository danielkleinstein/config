#!/usr/bin/env python3

import argparse
import requests
import sys
import time

DEFAULT_ENDPOINT = "https://api.sampleapis.com/countries/countries"

def fetch_endpoint(endpoint, interval=1, count=None, quiet=False):
    global total_requests
    total_requests = 0

    while True:
        response = requests.get(endpoint)
        total_requests += 1
        if not quiet:
            print(response.text)

        if count is not None and total_requests >= count:
            break

        time.sleep(interval)
        if not quiet:
            sys.stderr.write(f"Total requests made: {total_requests}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Access an endpoint at regular intervals.")
    parser.add_argument("-e", "--endpoint", default=DEFAULT_ENDPOINT, help=f"URL of the endpoint to access (default is {DEFAULT_ENDPOINT}).")
    parser.add_argument("-i", "--interval", type=float, default=1, help="Interval in seconds between requests (default is 1 second).")
    parser.add_argument("-c", "--count", type=int, help="Limit the number of requests to this count. If not provided, the script will run indefinitely.")
    parser.add_argument("-q", "--quiet", action="store_true", help="Suppress output. If provided, the response text and total requests made won't be printed.")
    args = parser.parse_args()

    start_time = time.time()

    try:
        fetch_endpoint(args.endpoint, args.interval, args.count, args.quiet)
    except Exception as e:
        print(f"An exception occurred: {e}")
    finally:
        end_time = time.time()
        elapsed_time = end_time - start_time
        print(f"\n\nTotal number of requests: {total_requests}")
        print(f"Elapsed time: {elapsed_time:.2f} seconds")