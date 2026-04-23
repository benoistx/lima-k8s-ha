# Troubleshooting

## Check node state

```bash
./scripts/status.sh
```

## Check bootstrap logs

```bash
for n in cp1 cp2 cp3 w1 w2; do
  echo "===== $n ====="
  tail -n 50 "bootstrap-$n.log"
  echo
done
```

## Check prep logs

```bash
for n in cp1 cp2 cp3 w1 w2; do
  echo "===== $n ====="
  tail -n 50 "prep-$n.log"
  echo
done
```

## Reset a node

```bash
./scripts/reset-node.sh cp2
```
