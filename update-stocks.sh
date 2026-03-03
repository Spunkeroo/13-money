#!/bin/bash
# Update stock + metals prices and push to GitHub
# Run manually: ./update-stocks.sh
# Or add to crontab: */5 6-16 * * 1-5 cd /Users/spunkart/13-money && ./update-stocks.sh

cd "$(dirname "$0")"

python3 - <<'PYEOF'
import json, urllib.request, time

# Stocks
symbols = ['SPY','QQQ','DIA','AAPL','MSFT','GOOGL','AMZN','NVDA','TSLA','META','JPM','V','BRK-B','UNH','JNJ','WMT','XOM','AMD']
results = {}

for sym in symbols:
    try:
        url = f'https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d&range=1d'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            meta = data['chart']['result'][0]['meta']
            price = meta['regularMarketPrice']
            prev = meta.get('previousClose') or meta.get('chartPreviousClose') or price
            change = round(price - prev, 4)
            pct = round((change / prev * 100) if prev > 0 else 0, 4)
            key = sym.replace('-', '.')
            results[key] = {'p': round(price, 2), 'c': round(change, 2), 'pct': round(pct, 2)}
    except Exception as e:
        print(f'  {sym}: FAILED - {e}')
    time.sleep(0.3)

# Metals (futures from Yahoo Finance)
metals_symbols = {'GC=F': 'gold', 'SI=F': 'silver', 'PL=F': 'platinum', 'PA=F': 'palladium'}
metals = {}

for sym, name in metals_symbols.items():
    try:
        url = f'https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d&range=1d'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            meta = data['chart']['result'][0]['meta']
            price = meta['regularMarketPrice']
            prev = meta.get('previousClose') or meta.get('chartPreviousClose') or price
            change = round(price - prev, 4)
            pct = round((change / prev * 100) if prev > 0 else 0, 4)
            metals[name] = {'p': round(price, 2), 'c': round(change, 2), 'pct': round(pct, 2)}
            print(f'  {name}: ${price:.2f} ({pct:+.2f}%)')
    except Exception as e:
        print(f'  {name}: FAILED - {e}')
    time.sleep(0.3)

output = {'updated': int(time.time()), 'stocks': results, 'metals': metals}
with open('stock-data.json', 'w') as f:
    json.dump(output, f, separators=(',', ':'))
print(f'Updated {len(results)} stocks + {len(metals)} metals at {time.strftime("%H:%M:%S")}')
PYEOF

git add stock-data.json
git diff --cached --quiet || (git commit -m "Update prices [automated]" && git push)
