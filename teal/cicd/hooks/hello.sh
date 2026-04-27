#!/bin/bash

echo "----------------------------------------"
echo "Ths is the Hello Webhook!"
echo "========================="
echo
echo "## Environment Variables:"
echo
printenv
echo
echo "## Post Data:"
echo
echo "$@"
echo "----------------------------------------"
