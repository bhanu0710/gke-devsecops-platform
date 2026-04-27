'use strict';
// tracing.js must be loaded BEFORE any other module via --require flag.
// It sets up the OpenTelemetry SDK so all Express HTTP spans are captured
// automatically without manual instrumentation in business logic files.

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  // OTEL_EXPORTER_OTLP_ENDPOINT env var overrides this default in-cluster URL
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector.monitoring:4317',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false }, // fs spans are noisy
    }),
  ],
  serviceName: 'user-service',
});

sdk.start();

process.on('SIGTERM', () => sdk.shutdown());
