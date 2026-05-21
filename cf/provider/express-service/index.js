const https = require('https');
const {
  ECSClient,
  CreateExpressGatewayServiceCommand,
  DeleteExpressGatewayServiceCommand,
  DescribeExpressGatewayServiceCommand,
  UpdateExpressGatewayServiceCommand,
} = require('@aws-sdk/client-ecs');

const ecs = new ECSClient({});
const POLL_INTERVAL_MS = 15000;
const POLL_TIMEOUT_MS = 12 * 60 * 1000;

exports.handler = async (event, context) => {
  console.log(JSON.stringify(event));

  try {
    const { RequestType, PhysicalResourceId, ResourceProperties, OldResourceProperties } = event;

    if (RequestType === 'Delete') {
      await deleteService(PhysicalResourceId);
      return sendResponse(event, context, 'SUCCESS', { Endpoint: '' }, PhysicalResourceId);
    }

    if (RequestType === 'Update') {
      assertImmutableProperties(ResourceProperties, OldResourceProperties);
      const service = await updateService(PhysicalResourceId, ResourceProperties);
      return sendResponse(event, context, 'SUCCESS', responseData(service), service.serviceArn);
    }

    const service = await createService(ResourceProperties);
    return sendResponse(event, context, 'SUCCESS', responseData(service), service.serviceArn);
  } catch (error) {
    console.error(error);
    return sendResponse(
      event,
      context,
      'FAILED',
      { Error: error.message || 'Unknown error' },
      event.PhysicalResourceId || context.logStreamName,
    );
  }
};

function assertImmutableProperties(next, previous = {}) {
  for (const property of ['ClusterName', 'InfrastructureRoleArn', 'ServiceName']) {
    if ((next[property] || '') !== (previous[property] || '')) {
      throw new Error(`${property} cannot be updated in-place. Recreate the stack to change it.`);
    }
  }
}

function buildServiceRequest(properties) {
  const request = {
    executionRoleArn: properties.ExecutionRoleArn,
    infrastructureRoleArn: properties.InfrastructureRoleArn,
    serviceName: properties.ServiceName,
    primaryContainer: {
      image: properties.ImageUri,
      containerPort: Number(properties.ContainerPort || 8080),
    },
  };

  if (properties.ClusterName) {
    request.cluster = properties.ClusterName;
  }

  if (properties.HealthCheckPath) {
    request.healthCheckPath = properties.HealthCheckPath;
  }

  if (properties.Cpu) {
    request.cpu = String(properties.Cpu);
  }

  if (properties.Memory) {
    request.memory = String(properties.Memory);
  }

  return request;
}

async function createService(properties) {
  const request = buildServiceRequest(properties);
  const response = await ecs.send(new CreateExpressGatewayServiceCommand(request));
  return waitForActive(response.service.serviceArn);
}

async function updateService(serviceArn, properties) {
  const request = buildServiceRequest(properties);
  delete request.infrastructureRoleArn;
  delete request.serviceName;
  delete request.cluster;

  await ecs.send(new UpdateExpressGatewayServiceCommand({
    serviceArn,
    ...request,
  }));

  return waitForActive(serviceArn);
}

async function deleteService(serviceArn) {
  if (!serviceArn || serviceArn === 'FAILED') {
    return;
  }

  try {
    await ecs.send(new DeleteExpressGatewayServiceCommand({ serviceArn }));
  } catch (error) {
    if (error.name === 'ServiceNotFoundException' || error.name === 'ClusterNotFoundException') {
      return;
    }
    throw error;
  }
}

async function waitForActive(serviceArn) {
  const deadline = Date.now() + POLL_TIMEOUT_MS;

  while (Date.now() < deadline) {
    const response = await ecs.send(new DescribeExpressGatewayServiceCommand({ serviceArn }));
    const service = response.service;
    const status = service?.status?.statusCode;
    const endpoint = findEndpoint(service);

    if (status === 'ACTIVE' && endpoint) {
      return service;
    }

    if (status === 'INACTIVE') {
      throw new Error(`Express service ${serviceArn} became INACTIVE during deployment.`);
    }

    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }

  throw new Error(`Timed out waiting for express service ${serviceArn} to become ACTIVE.`);
}

function responseData(service) {
  const endpoint = findEndpoint(service);
  return {
    Endpoint: endpoint,
    HelloUrl: endpoint ? `${endpoint}/hello` : '',
    ServiceArn: service.serviceArn,
    ServiceName: service.serviceName,
  };
}

function findEndpoint(service) {
  for (const configuration of service?.activeConfigurations || []) {
    for (const path of configuration.ingressPaths || []) {
      if (path.accessType === 'PUBLIC' && path.endpoint) {
        return path.endpoint;
      }
    }
  }
  return '';
}

function sendResponse(event, context, status, data, physicalResourceId) {
  const responseBody = JSON.stringify({
    Status: status,
    Reason: `See CloudWatch Logs: ${context.logStreamName}`,
    PhysicalResourceId: physicalResourceId || context.logStreamName,
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId,
    Data: data,
  });

  const url = new URL(event.ResponseURL);
  const options = {
    hostname: url.hostname,
    path: `${url.pathname}${url.search}`,
    method: 'PUT',
    headers: {
      'content-length': Buffer.byteLength(responseBody),
      'content-type': '',
    },
  };

  return new Promise((resolve, reject) => {
    const request = https.request(options, (response) => {
      response.on('data', () => undefined);
      response.on('end', resolve);
    });
    request.on('error', reject);
    request.write(responseBody);
    request.end();
  });
}
