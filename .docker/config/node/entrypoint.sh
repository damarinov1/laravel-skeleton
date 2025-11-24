#!/bin/sh
set -e

yarn install

exec yarn run dev --host
