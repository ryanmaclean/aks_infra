#!/usr/bin/env bash

helm install datadog -f datadog-values.yaml --set datadog.apiKey="${DD_API}" stable/datadog
