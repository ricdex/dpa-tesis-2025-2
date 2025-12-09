#!/usr/bin/env node

import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { MlRetriesStack } from '../lib/ml-retries-stack';

const app = new cdk.App();

new MlRetriesStack(app, 'MlRetriesStack', {
  stackName: 'ml-retries-stack',
  description: 'AWS CDK Stack for ML-based Payment Retry Prediction',
  env: {
    region: process.env.AWS_REGION || 'us-east-1',
    account: process.env.AWS_ACCOUNT_ID || process.env.CDK_DEFAULT_ACCOUNT,
  },
});

app.synth();
