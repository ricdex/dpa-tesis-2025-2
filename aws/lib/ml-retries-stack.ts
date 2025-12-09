import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Platform } from 'aws-cdk-lib/aws-ecr-assets';
import * as stepfunctions from 'aws-cdk-lib/aws-stepfunctions';
import * as stepfunctions_tasks from 'aws-cdk-lib/aws-stepfunctions-tasks';
import { Construct } from 'constructs';

export class MlRetriesStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ============================================
    // 1. S3 Bucket para almacenar el modelo
    // ============================================
    const modelBucket = new s3.Bucket(this, 'ModelBucket', {
      bucketName: `ml-retries-model-${this.account}-${this.region}`,
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    cdk.Tags.of(modelBucket).add('Component', 'ModelStorage');
    cdk.Tags.of(modelBucket).add('Project', 'MLRetries');

    // ============================================
    // 2. Lambda de Inferencia con DockerImageFunction
    // ============================================

    // Log Group para la Lambda
    const lambdaLogGroup = new logs.LogGroup(this, 'InferenceLambdaLogGroup', {
      logGroupName: '/aws/lambda/ml-retries-inference',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Crear la función Lambda basada en Docker
    const inferenceLambda = new lambda.DockerImageFunction(
      this,
      'InferenceLambda',
      {
        code: lambda.DockerImageCode.fromImageAsset('./lambda', {
          file: 'Dockerfile',
          platform: Platform.LINUX_AMD64,
        }),
        architecture: lambda.Architecture.X86_64,
        timeout: cdk.Duration.seconds(60),
        memorySize: 512,
        environment: {
          MODEL_BUCKET: modelBucket.bucketName,
          MODEL_KEY: 'models/mejor_modelo.pkl',
          THRESHOLD: '0.1',
          LOG_LEVEL: 'DEBUG',
        },
        logGroup: lambdaLogGroup,
      }
    );

    // Dar permisos a la Lambda para leer del S3 Bucket
    modelBucket.grantRead(inferenceLambda);

    cdk.Tags.of(inferenceLambda).add('Component', 'InferenceLambda');
    cdk.Tags.of(inferenceLambda).add('Project', 'MLRetries');

    // ============================================
    // 3. Step Functions State Machine
    // ============================================

    // Crear un estado de inicio que itera sobre una lista de transacciones
    // Utilizamos un Map state para procesar múltiples reintento

    const invokeInferenceTask = new stepfunctions_tasks.LambdaInvoke(
      this,
      'InvokeInferenceLambda',
      {
        lambdaFunction: inferenceLambda,
        outputPath: '$.Payload.body',
      }
    );

    // Estado final para ambas ramas del Choice
    const finalizeResult = new stepfunctions.Pass(this, 'FinalizeResult');

    // Estados para decisión de reintento
    const retryApprovedState = new stepfunctions.Pass(
      this,
      'ReintentoAprobado',
      {
        result: stepfunctions.Result.fromObject({
          decision: 'APROBADO',
          message: 'Reintento recomendado según el modelo',
        }),
        resultPath: '$.decision_result',
      }
    ).next(finalizeResult);

    const retryRejectedState = new stepfunctions.Pass(
      this,
      'ReintentoRechazado',
      {
        result: stepfunctions.Result.fromObject({
          decision: 'RECHAZADO',
          message: 'No se recomienda el reintento según el modelo',
        }),
        resultPath: '$.decision_result',
      }
    ).next(finalizeResult);

    // Choice state para decidir basándose en la respuesta de la Lambda
    const decisionChoice = new stepfunctions.Choice(this, 'DecidirReintento')
      .when(
        stepfunctions.Condition.booleanEquals('$.reintentar', true),
        retryApprovedState
      )
      .otherwise(retryRejectedState);

    // Chain: invoke lambda -> decision
    const chainProcess = invokeInferenceTask.next(decisionChoice);

    // Map state que itera sobre un array de transacciones del input
    const mapState = new stepfunctions.Map(this, 'ProcessRetriesMap', {
      maxConcurrency: 5,
      itemsPath: '$.retries',
      resultPath: '$.results',
    });

    mapState.itemProcessor(chainProcess);

    // Definir la máquina de estados
    const stateMachineDefinition = new stepfunctions.Pass(
      this,
      'PrepareInput'
    ).next(mapState).next(
      new stepfunctions.Pass(this, 'FinalOutput')
    );

    const retriesStateMachine = new stepfunctions.StateMachine(
      this,
      'RetriesStateMachine',
      {
        definition: stateMachineDefinition,
        stateMachineType: stepfunctions.StateMachineType.STANDARD,
        tracingEnabled: true,
      }
    );

    cdk.Tags.of(retriesStateMachine).add('Component', 'StateMachine');
    cdk.Tags.of(retriesStateMachine).add('Project', 'MLRetries');

    // ============================================
    // 4. Outputs
    // ============================================

    new cdk.CfnOutput(this, 'ModelBucketName', {
      value: modelBucket.bucketName,
      description: 'S3 Bucket para almacenar el modelo',
      exportName: 'MLRetries-ModelBucket',
    });

    new cdk.CfnOutput(this, 'InferenceLambdaArn', {
      value: inferenceLambda.functionArn,
      description: 'ARN de la Lambda de Inferencia',
      exportName: 'MLRetries-InferenceLambdaArn',
    });

    new cdk.CfnOutput(this, 'StateMachineArn', {
      value: retriesStateMachine.stateMachineArn,
      description: 'ARN de la State Machine',
      exportName: 'MLRetries-StateMachineArn',
    });

    new cdk.CfnOutput(this, 'LambdaLogGroupName', {
      value: lambdaLogGroup.logGroupName,
      description: 'CloudWatch Log Group de la Lambda',
      exportName: 'MLRetries-LambdaLogGroup',
    });
  }
}
