#!/usr/bin/env python3
import sys
import json
import re
import time
import urllib.request
import urllib.error

URL = "http://127.0.0.1:3000/api/chat/completions"
API_KEY = "sk-prompt-engineer-shortcut"

def count_cursor_jumps(text):
    tokens = re.findall(r'\w+|[^\w\s]+', text)
    return len(tokens)

def query_open_webui(payload, retries=3, backoff=2):
    req = urllib.request.Request(
        URL,
        data=json.dumps(payload).encode('utf-8'),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {API_KEY}'
        },
        method='POST'
    )
    
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            err_body = e.read().decode('utf-8')
            # Check if it is a transient error (e.g. 503 Service Unavailable, 429 Rate Limit, or 400 wrapper containing a 503/UNAVAILABLE)
            is_transient = (
                e.code in [429, 503, 504] or
                "503" in err_body or
                "UNAVAILABLE" in err_body or
                "high demand" in err_body
            )
            
            if is_transient and attempt < retries:
                sleep_time = backoff ** (attempt + 1)
                print(f"[Warning] Upstream API busy (attempt {attempt + 1}/{retries + 1}). Retrying in {sleep_time}s...", file=sys.stderr)
                time.sleep(sleep_time)
                continue
            else:
                raise urllib.error.HTTPError(e.url, e.code, f"{e.reason} - {err_body}", e.headers, e.fp)
        except Exception as e:
            if attempt < retries:
                sleep_time = backoff ** (attempt + 1)
                print(f"[Warning] Connection error (attempt {attempt + 1}/{retries + 1}). Retrying in {sleep_time}s...", file=sys.stderr)
                time.sleep(sleep_time)
                continue
            else:
                raise e

def main():
    if len(sys.argv) < 2:
        print("Usage: prompt_engineer.py <text_file>", file=sys.stderr)
        sys.exit(1)
        
    file_path = sys.argv[1]
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            raw_text = f.read().strip()
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)
        
    if not raw_text:
        print("No text to process.", file=sys.stderr)
        sys.exit(1)
        
    # Calculate cursor jumps
    jumps = count_cursor_jumps(raw_text)
    with open('/tmp/f9_jumps.txt', 'w') as jf:
        jf.write(str(jumps))
        
    payload = {
        "model": "prompt-engineer",
        "messages": [
            {
                "role": "user",
                "content": raw_text
            }
        ]
    }
    
    try:
        res_data = query_open_webui(payload)
        output_text = res_data['choices'][0]['message']['content']
        print(output_text.strip())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
