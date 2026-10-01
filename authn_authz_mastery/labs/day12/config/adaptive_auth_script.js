// IS 7.3 Adaptive Authentication Script
// Application: Banking Portal
// Steps configured in Console:
//   Step 1: BasicAuthenticator (username + password)
//   Step 2: TOTP (for payment-approvers)
//   Step 3: EmailOTP (for new IP detection)

var onLoginRequest = function(context) {
    executeStep(1, {
        onSuccess: function(context) {
            var user = context.steps[1].subject;

            // Rule 1: Payment approvers always require TOTP (Step 2)
            if (isMemberOfRole(user, 'payment-approvers')) {
                executeStep(2, {
                    onFail: function(context) {
                        fail({
                            errorCode: 'AUTH_FAILED',
                            errorMessage: 'TOTP verification failed'
                        });
                    }
                });
                return; // early return: don't evaluate other rules
            }

            // Rule 2: Fraud-flagged accounts are denied entirely
            var fraudFlag = user.localClaims['http://wso2.org/claims/isFraudFlagged'];
            if (fraudFlag === 'true') {
                fail({
                    errorCode: 'ACCOUNT_BLOCKED',
                    errorMessage: 'Account suspended for security review'
                });
                return;
            }

            // Rule 3: New IP address triggers email OTP (Step 3)
            var lastKnownIP = user.localClaims['http://wso2.org/claims/lastLoginIP'];
            if (lastKnownIP && context.request.ip !== lastKnownIP) {
                executeStep(3, {
                    onFail: function(context) {
                        fail({
                            errorCode: 'AUTH_FAILED',
                            errorMessage: 'Email OTP verification failed'
                        });
                    }
                });
            }
            // If no rule triggered: user passes with Step 1 only
        },
        onFail: function(context) {
            fail({
                errorCode: 'INVALID_CREDENTIALS',
                errorMessage: 'Username or password incorrect'
            });
        }
    });
};
