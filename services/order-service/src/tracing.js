'use strict';
// order-service tracing — identical structure to user-service.
// The key difference: when order-service calls user-service or product-service,
// it automatically propagates W3C traceparent headers, creating a distributed trace
// spanning all 3 services visible in Grafana Tempo.

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector.monitoring:4317',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
  serviceName: 'order-service',
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());
