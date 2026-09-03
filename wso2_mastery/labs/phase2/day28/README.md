# Lab: Day 28 — GW Log4j2 Loggers (Source Reading)

## Overview

In this lab, you'll explore the WSO2 API Manager Gateway source distribution and locate the **5 GW-specific log4j2 loggers** 
mentioned in Day 28 content. This is a source code reading exercise to familiarize yourself with the gateway's logging architecture.

## Objective

Find and document the following 5 loggers in the WSO2 Gateway log4j2 config:

1. Core gateway handler logger
2. Security handler (JWT validation)
3. Throttling handler
4. Authentication handler (subscription checks)
5. JWT validator (detailed token analysis)

Extract their exact logger names and understand what each one logs.

## Files to Reference

**WSO2 Gateway Distribution:**
```
/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0/
```

**Log4j2 Config File:**
```
wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties
```

## Instructions

### Step 1: Locate the Log4j2 Configuration File

Navigate to the WSO2 Gateway distribution and find the log4j2.properties file:

```bash
ls -la /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties
```

### Step 2: Search for Gateway-Specific Loggers

Open the log4j2.properties file and search for loggers containing "apimgt.gateway" or "gateway":

```bash
cat /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties \
  | grep -i "logger.*gateway\|logger.*apimgt"
```

### Step 3: Document the 5 Loggers

For each logger you find, document:
- Logger name (from `.name =` field)
- Current default level
- What it logs (based on the name and Day 28 content)
- When you'd enable it

### Step 4: Answer These Questions

1. **What is the fully qualified logger name for the core gateway handler?**

2. **Which logger is responsible for JWT signature validation, and what level does it default to?**

3. **What does the throttling handler logger name contain?**

4. **If you enable DEBUG on all 5 loggers, where would the logs appear?**

5. **In a containerized deployment (Docker/ECS), how would you apply log4j2 config changes?**

## Hints

- Look for loggers with package names starting with `org.wso2.carbon.apimgt.gateway`
- Some loggers may already exist in the file; others might need to be added
- The security handlers are typically under `.handlers.security` packages
- Document both the logger name and the fully qualified class package

## Expected Output

Your answer should document each of the 5 loggers in a format like:

```
1. Logger: org.wso2.carbon.apimgt.gateway
   Default Level: INFO (usually)
   What It Logs: General gateway operations
   When to Enable: Trace overall request flow
```

## Verification

You'll know you've found the right loggers when:
- [ ] All 5 loggers have names containing "org.wso2.carbon.apimgt.gateway"
- [ ] Logger names are hierarchical (more specific ones are sub-packages)
- [ ] You can explain what each one logs
- [ ] You've located the correct file path in the distribution

## Teardown

No cleanup needed for this lab — it's source reading only. You didn't modify the gateway.

