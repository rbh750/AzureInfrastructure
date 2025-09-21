param authManagedIdentityUrl string

var policyContent = loadTextContent('ApimPolicy.xml')
var updatedPolicyContent = replace(policyContent, '{{FNAP-URL}}', authManagedIdentityUrl)
var escapedPolicyContent = replace(updatedPolicyContent, '"', '\\"')

output policyContent string = escapedPolicyContent
