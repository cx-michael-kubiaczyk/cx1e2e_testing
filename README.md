This repository exists specifically for integration testing of the Cx1e2e tool and the underlying Cx1ClientGo library.
You can find details about Cx1e2e here: github.com/cxpsemea/cx1e2e
You can find details about Cx1ClientGo here: github.com/cxpsemea/Cx1ClientGo

This repository has two workflows, both of which consume the following Github secrets
- CANARY_CX1_URL: URL for your Cx1, for example https://eu.ast.checkmarx.net
- CANARY_IAM_URL: URL for your Cx1, for example https://eu.iam.checkmarx.net
- CANARY_TENANT: CheckmarxOne Tenant name, eg my_tenant
- CANARY_CLIENT_ID: CheckmarxOne OIDC Client ID - this client should have tenant-level ast-admin and iam-admin permissions to run the full test suite
- CANARY_CLIENT_SECRET: CheckmarxOne OIDC Client Secret
- WEBHOOK_URL: optional MS Teams Webhook URL, to post a message with the summary & failures of each run to a channel

The Main workflow clones the main branch of Cx1e2e and Cx1ClientGo and uses both to execute the full test set against the target environment.
The Staging workflow clones main|staging branch instead, if staging != main, and only if one of the repos has staging!=main. This is the next-release testing workflow and you probably don't need it.

You can clone this repo and configure your own repository secrets to set up your own nightly "main" branch testing workflow.
