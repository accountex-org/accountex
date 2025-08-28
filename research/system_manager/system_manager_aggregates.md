# Accountex System Manager - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the System Manager domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core System Aggregates

### SystemEnvironment

**Purpose**: Maintains the overall system state and configuration for the entire Accountex platform.

**Description**: The SystemEnvironment aggregate serves as the central control point for system-wide operations. It handles system initialization, bootstrap processes, global parameter management with hierarchical override capabilities, and system date/time management across all modules. This aggregate ensures system-wide consistency while allowing module-specific configuration overrides.

**Key Responsibilities**:
- System initialization and bootstrap processes
- Global parameter management with hierarchical override capabilities  
- System date and time management across all modules
- Module registry and availability tracking
- Performance monitoring and resource allocation
- Integration endpoint management for external systems

**State Structure**:
```elixir
defstruct [
  :environment_id,
  :system_date,
  :initialization_status,
  :global_parameters,
  :active_modules,
  :system_version,
  :deployment_mode, # :on_premise, :cloud, :hybrid
  :integration_endpoints,
  :performance_metrics
]
```

**Key Commands**: `InitializeSystem`, `UpdateSystemConfiguration`, `SetSystemDate`, `ConfigureIntegrationEndpoint`, `UpdatePerformanceParameters`

**Key Events**: `SystemInitialized`, `SystemConfigurationUpdated`, `SystemDateChanged`, `IntegrationEndpointConfigured`, `PerformanceParametersUpdated`

---

### CompanyHierarchy

**Purpose**: Models complex relationships between legal entities, subsidiaries, and consolidated reporting structures.

**Description**: The CompanyHierarchy aggregate manages unlimited companies with flexible parent-child relationships, shared resources, and inter-company transactions. Each company maintains its own fiscal calendar, chart of accounts, and security context while participating in consolidated operations. It supports multi-level hierarchies with cross-company resource sharing and consolidation elimination rules.

**Key Responsibilities**:
- Hierarchical company structure with multiple levels
- Cross-company resource sharing (customers, vendors, warehouses)
- Inter-company transaction management and elimination
- Consolidated financial reporting with currency conversion
- Company-specific configuration and customization
- Regional compliance support per legal entity

**State Structure**:
```elixir
defstruct [
  :hierarchy_id,
  :companies,        # Map of company_id => Company struct
  :relationships,    # Parent-child relationships
  :consolidation_mappings,
  :shared_resources,
  :active_company_locks
]
```

**Key Commands**: `CreateCompany`, `UpdateCompanySettings`, `LockCompany`, `UnlockCompany`, `MapConsolidationAccounts`, `ShareResource`, `InitiateCompanyArchive`

**Key Events**: `CompanyCreated`, `CompanySettingsUpdated`, `CompanyLocked`, `CompanyUnlocked`, `ConsolidationMappingCreated`, `ResourceShared`, `CompanyArchived`

---

### UserManagement

**Purpose**: Handles comprehensive user lifecycle, authentication, authorization, and security policy enforcement.

**Description**: The UserManagement aggregate implements a multi-layered security model with role-based access control (RBAC) and attribute-based enhancements. It manages user provisioning, authentication factors, role assignments, group memberships, password policies, and session control. The aggregate maintains a complete audit trail of all security-related actions and integrates with external identity providers.

**Key Responsibilities**:
- User account provisioning and lifecycle management
- Multi-factor authentication coordination
- Role-based and attribute-based authorization
- Password policy enforcement and history tracking
- Session management and concurrent login control
- Security violation detection and response
- Integration with external identity providers

**State Structure**:
```elixir
defstruct [
  :user_id,
  :username,
  :authentication_factors,
  :assigned_roles,
  :group_memberships,
  :access_restrictions,
  :password_history,
  :session_info,
  :security_violations
]
```

**Key Commands**: `CreateUser`, `UpdateUserRoles`, `EnforcePasswordChange`, `LockUserAccount`, `CreateSecurityRole`, `SetFieldLevelSecurity`, `TerminateUserSession`, `GrantTemporaryAccess`

**Key Events**: `UserCreated`, `UserRolesUpdated`, `PasswordChanged`, `UserAccountLocked`, `SecurityRoleCreated`, `FieldSecurityConfigured`, `UserSessionTerminated`, `TemporaryAccessGranted`

---

### ModuleRegistry

**Purpose**: Manages the lifecycle of pluggable Accountex modules with dynamic loading capabilities.

**Description**: The ModuleRegistry aggregate tracks available modules, their dependencies, activation status, and health using Elixir's dynamic loading capabilities. It implements a behavior-based plugin system where modules must conform to the `Accountex.ModuleBehaviour` specification, enabling runtime module loading and unloading. The registry handles dependency resolution, license management, and module health monitoring.

**Key Responsibilities**:
- Dependency resolution and circular dependency prevention
- Module activation sequencing based on dependency graphs
- Health monitoring with automatic recovery mechanisms
- Event propagation for module state changes
- Configuration distribution to active modules
- Resource cleanup on module deactivation
- License allocation and tracking

**State Structure**:
```elixir
defstruct [
  :registry_id,
  :registered_modules,
  :activation_status,
  :dependency_graph,
  :license_assignments,
  :module_health,
  :configuration_overrides
]
```

**Key Commands**: `RegisterModule`, `ActivateModule`, `DeactivateModule`, `AssignModuleLicense`, `RevokeLicense`, `UpdateModuleConfiguration`, `CheckModuleHealth`

**Key Events**: `ModuleRegistered`, `ModuleActivated`, `ModuleDeactivated`, `LicenseAssigned`, `LicenseRevoked`, `ModuleConfigurationUpdated`, `ModuleHealthChecked`

---

## Fiscal and Financial Aggregates

### FiscalCalendar

**Purpose**: Manages fiscal year structures, accounting periods, and posting date validation across companies.

**Description**: The FiscalCalendar aggregate defines and manages fiscal year structures for each company, including regular accounting periods and special periods (such as Period 13 for adjustments). It handles period opening and closing, validates posting dates, and supports multiple calendar types (monthly, quarterly, custom). The aggregate coordinates with other modules during period-end closing processes.

**Key Responsibilities**:
- Fiscal year and period structure definition
- Accounting period status management (open/closed/soft-closed)
- Posting date validation and restrictions
- Special period management (adjustment periods)
- Multi-company calendar synchronization
- Period-end closing coordination

**State Structure**:
```elixir
defstruct [
  :calendar_id,
  :fiscal_year_start,
  :period_structure,    # :monthly, :quarterly, :custom
  :periods,            # List of period definitions
  :special_periods,    # Period 13, opening balance, etc.
  :current_period,
  :posting_restrictions
]
```

**Key Commands**: `CreateFiscalCalendar`, `OpenAccountingPeriod`, `CloseAccountingPeriod`, `CreateAdjustmentPeriod`, `MapSubsidiaryPeriods`, `InitiatePeriodEndClose`, `ReopenClosedPeriod`

**Key Events**: `FiscalCalendarCreated`, `AccountingPeriodOpened`, `AccountingPeriodClosed`, `AdjustmentPeriodCreated`, `SubsidiaryPeriodsMapped`, `PeriodEndCloseInitiated`, `ClosedPeriodReopened`

---

## Security and Compliance Aggregates

### SecurityContext

**Purpose**: Implements multi-layered security model with comprehensive authorization and fraud prevention.

**Description**: The SecurityContext aggregate manages authentication, authorization, session control, and security policy enforcement across all Accountex modules. It implements role-based access control (RBAC) with attribute-based enhancements, including company-level, module-level, function-level, and field-level security. The aggregate includes fraud prevention mechanisms such as behavioral analytics, approval workflows, and session management.

**Key Responsibilities**:
- Multi-layered authorization (company/module/function/field levels)
- Fraud prevention and behavioral analytics
- Approval workflow enforcement
- Separation of duties validation
- Session security and concurrent login prevention
- Security violation detection and response

**State Structure**:
```elixir
defstruct [
  :security_context_id,
  :active_sessions,
  :security_policies,
  :approval_workflows,
  :behavioral_baselines,
  :fraud_indicators,
  :access_violations
]
```

---

### GroupHierarchy

**Purpose**: Manages hierarchical user group structures with inherited permissions and restrictions.

**Description**: The GroupHierarchy aggregate handles complex user group relationships with permission inheritance. It calculates effective permissions by merging direct roles, group roles, and inherited roles while applying restrictions and separation of duties rules. The aggregate supports nested group structures and dynamic permission resolution.

**Key Responsibilities**:
- Hierarchical group structure management
- Permission inheritance calculation
- Group membership management
- Conflict resolution for overlapping permissions
- Restriction enforcement
- Separation of duties compliance

**State Structure**:
```elixir
defstruct [
  :group_id,
  :group_name,
  :parent_group,
  :child_groups,
  :direct_members,      # Users directly in group
  :inherited_members,   # Users from child groups
  :permissions,
  :restrictions
]
```

---

## Audit and Compliance Aggregates

### AuditTrail

**Purpose**: Maintains comprehensive audit trails for all system activities with compliance-grade tracking.

**Description**: The AuditTrail aggregate captures detailed audit information for all system activities, including entity changes, user actions, and system events. It implements data classification for compliance, risk scoring, and behavioral analysis. The aggregate supports various audit requirements including SOX compliance and provides comprehensive audit analysis capabilities.

**Key Responsibilities**:
- Comprehensive activity logging and tracking
- Data classification for compliance requirements
- Risk scoring and anomaly detection
- Audit data analysis and reporting
- Retention policy enforcement
- Regulatory compliance support

---

## Operational Aggregates

### LicenseManager

**Purpose**: Manages software licenses, allocations, and usage compliance across all modules.

**Description**: The LicenseManager aggregate handles license pool management, assignment tracking, usage metrics, and compliance monitoring. It supports various license types, concurrent usage limits, and expiration management while providing usage analytics for compliance and optimization purposes.

**Key Responsibilities**:
- License pool management and allocation
- Usage tracking and compliance monitoring
- Concurrent user limit enforcement
- License expiration management
- Usage analytics and reporting
- Cost optimization recommendations

**State Structure**:
```elixir
defstruct [
  :license_pool,        # Available licenses by type
  :assignments,         # Current license assignments
  :usage_metrics,       # Usage tracking for compliance
  :restrictions,        # License limitations
  :expiration_dates     # License validity periods
]
```

---

### TenantManager

**Purpose**: Handles multi-tenant architecture with support for multiple tenancy models.

**Description**: The TenantManager aggregate supports three multi-tenancy models: shared database with separate schemas, shared database with shared schema, and separate databases. It manages schema creation, connection pooling, and tenant context switching while ensuring proper data isolation and cross-tenant operations for consolidation.

**Key Responsibilities**:
- Multi-tenant architecture management
- Schema creation and migration coordination
- Tenant context switching
- Data isolation enforcement
- Cross-tenant consolidation operations
- Connection pool management

---

### InterCompanyManager

**Purpose**: Manages transactions and operations between companies in the hierarchy.

**Description**: The InterCompanyManager aggregate handles transactions that span multiple companies within the same hierarchy. It creates reciprocal entries, manages consolidation elimination entries, and ensures proper accounting treatment of inter-company activities. The aggregate supports complex multi-entity scenarios with automated elimination and reporting.

**Key Responsibilities**:
- Inter-company transaction processing
- Reciprocal entry creation
- Consolidation elimination management
- Multi-entity reporting support
- Transfer pricing compliance
- Cross-company reconciliation

---

## Data Management Aggregates

### DataArchiver

**Purpose**: Manages data lifecycle and intelligent archival operations across the system.

**Description**: The DataArchiver aggregate implements intelligent data archival policies, identifying archivable data based on retention requirements and business rules. It handles data compression, encryption, and migration to cost-optimized storage while maintaining searchable metadata indexes and ensuring regulatory compliance.

**Key Responsibilities**:
- Data lifecycle management
- Intelligent archival policy execution
- Data compression and encryption
- Archive storage management
- Metadata indexing and searchability
- Retention policy compliance

---

### IntegrityMonitor

**Purpose**: Continuously monitors and validates data integrity across the entire system.

**Description**: The IntegrityMonitor aggregate performs comprehensive data integrity checks including referential integrity, financial balance validation, audit trail continuity, and orphaned record detection. It generates integrity reports and triggers corrective actions when inconsistencies are detected.

**Key Responsibilities**:
- Referential integrity validation
- Financial balance verification
- Audit trail continuity checking
- Orphaned record detection
- Document attachment validation
- Integrity report generation

---

### MaintenanceOrchestrator

**Purpose**: Coordinates system maintenance operations with minimal business impact.

**Description**: The MaintenanceOrchestrator aggregate manages scheduled maintenance windows, including database maintenance, index rebuilding, statistics updates, and system optimization tasks. It identifies low-activity periods, coordinates with all modules, and ensures system integrity throughout maintenance operations.

**Key Responsibilities**:
- Maintenance window scheduling
- Low-activity period identification
- Multi-module coordination during maintenance
- Database optimization tasks
- System integrity verification
- User notification management

---

## Agent Management Aggregates

### FeatureFlags

**Purpose**: Manages feature availability across modules with dynamic enablement capabilities.

**Description**: The FeatureFlags aggregate implements feature toggle functionality with support for license-based features, company-specific overrides, user-specific beta access, and global feature flags. It integrates with the Jido agent framework to provide dynamic feature availability based on multiple criteria.

**Key Responsibilities**:
- Feature toggle management
- License-based feature enablement
- Company and user-specific overrides
- Beta access management
- Feature usage analytics
- A/B testing support

---

### PasswordPolicy

**Purpose**: Enforces SOX-compliant password policies with advanced security features.

**Description**: The PasswordPolicy aggregate implements comprehensive password policy enforcement including complexity validation, dictionary checking, breach database verification, and password history tracking. It supports automated password rotation policies and integrates with the Jido agent framework for intelligent security management.

**Key Responsibilities**:
- Password complexity validation
- Password history enforcement
- Breach database checking
- Automated rotation policies
- SOX compliance enforcement
- Security strength assessment

---

### AuditAnalyzer

**Purpose**: Performs real-time audit analysis and anomaly detection using machine learning.

**Description**: The AuditAnalyzer aggregate continuously analyzes audit event streams to detect unusual patterns, identify high-risk activities, and check for compliance violations. It uses machine learning models and statistical analysis to establish behavioral baselines and generate security alerts.

**Key Responsibilities**:
- Real-time audit stream analysis
- Anomaly detection and pattern recognition
- Behavioral baseline establishment
- Risk assessment and scoring
- Compliance violation detection
- Security alert generation

---

## Integration and Communication Aggregates

### ModuleProxy

**Purpose**: Implements circuit breaker patterns for graceful degradation when modules become unavailable.

**Description**: The ModuleProxy aggregate manages inter-module communication with fault tolerance capabilities. It implements circuit breaker patterns, tracks success/failure rates, and provides fallback mechanisms when modules become unavailable or degraded. The aggregate ensures system resilience through intelligent routing and recovery strategies.

**Key Responsibilities**:
- Inter-module communication management
- Circuit breaker pattern implementation
- Failure rate tracking and threshold management
- Fallback mechanism coordination
- Module health status monitoring
- Communication retry and backoff strategies

---

### EventStore

**Purpose**: Manages partitioned event streams for scalability and performance optimization.

**Description**: The EventStore aggregate implements partitioned event streams with configurable retention policies based on data types and compliance requirements. It optimizes event storage and retrieval while maintaining complete audit trails and supporting temporal queries over event history.

**Key Responsibilities**:
- Event stream partitioning and optimization
- Retention policy enforcement
- Event indexing and query optimization
- Archive management for historical events
- Performance monitoring and tuning
- Compliance-driven retention management

---

## Summary

The System Manager domain contains **13 primary aggregates** that collectively provide:

- **System Control**: SystemEnvironment for global state management
- **Multi-Tenancy**: CompanyHierarchy and TenantManager for enterprise structure
- **Security**: UserManagement, SecurityContext, GroupHierarchy, and PasswordPolicy for comprehensive security
- **Compliance**: AuditTrail and AuditAnalyzer for regulatory compliance
- **Operations**: ModuleRegistry, LicenseManager, and ModuleProxy for operational excellence
- **Data Management**: DataArchiver, IntegrityMonitor, and MaintenanceOrchestrator for data lifecycle
- **Infrastructure**: EventStore and FeatureFlags for technical infrastructure

Each aggregate maintains clear boundaries and communicates through well-defined events, ensuring loose coupling while maintaining consistency within aggregate boundaries. The design supports the distributed, event-driven architecture required for enterprise-scale ERP systems.