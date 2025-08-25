# Accountex System Manager business logic design

## Architecture overview

The Accountex System Manager serves as the central nervous system of the ERP platform, providing foundational services for system administration, security, multi-company management, and module orchestration. Built on Elixir's actor model with Ash framework for domain modeling, Commanded for event-sourcing, and Jido for autonomous operations, the System Manager implements a distributed, event-driven architecture that supports dynamic module availability.

The business logic layer leverages **bounded contexts** to organize related functionality, with each context containing aggregates, commands, events, and process managers. The System Manager acts as both a standalone module and an integration hub, exposing services that other Accountex modules consume while maintaining loose coupling through event-driven communication.

## Core business logic components and their responsibilities

### System control and environment management

The System Manager implements a **SystemEnvironment** aggregate that maintains the overall system state and configuration. This aggregate handles system initialization, environment setup, and runtime configuration management through commands like `InitializeSystem`, `UpdateSystemConfiguration`, and `SetSystemDate`. The aggregate ensures system-wide consistency while allowing module-specific overrides.

**Key responsibilities include:**
- System initialization and bootstrap processes
- Global parameter management with hierarchical override capabilities  
- System date and time management across all modules
- Module registry and availability tracking
- Performance monitoring and resource allocation
- Integration endpoint management for external systems

### Module orchestration engine

A **ModuleRegistry** aggregate manages the lifecycle of pluggable Accountex modules. Using Elixir's dynamic loading capabilities, it tracks available modules, their dependencies, activation status, and health. The registry implements a behavior-based plugin system where modules must conform to the `Accountex.ModuleBehaviour` specification, enabling runtime module loading and unloading.

**Module coordination patterns:**
- Dependency resolution and circular dependency prevention
- Module activation sequencing based on dependency graphs
- Health monitoring with automatic recovery mechanisms
- Event propagation for module state changes
- Configuration distribution to active modules
- Resource cleanup on module deactivation

### Security and authorization engine

The **SecurityContext** aggregate implements a multi-layered security model combining role-based access control (RBAC) with attribute-based enhancements. It manages authentication, authorization, session control, and security policy enforcement across all Accountex modules. The engine integrates with Ash's policy framework for declarative authorization rules while maintaining an event log of all security-related actions.

**Security patterns implemented:**
- Hierarchical role definitions with permission inheritance
- Dynamic authorization based on context (time, location, company)
- Separation of duties enforcement
- Privileged access management for administrative functions
- Security event monitoring and threat detection
- Compliance-oriented audit trail generation

### Multi-tenancy and company management

The **CompanyHierarchy** aggregate models the complex relationships between legal entities, subsidiaries, and consolidated reporting structures. It supports unlimited companies with flexible parent-child relationships, shared resources, and inter-company transactions. Each company maintains its own fiscal calendar, chart of accounts, and security context while participating in consolidated operations.

**Multi-company capabilities:**
- Hierarchical company structure with multiple levels
- Cross-company resource sharing (customers, vendors, warehouses)
- Inter-company transaction management and elimination
- Consolidated financial reporting with currency conversion
- Company-specific configuration and customization
- Regional compliance support per legal entity

## Event-sourced domain models and aggregates

### SystemEnvironment aggregate

```elixir
defmodule Accountex.SystemManager.Aggregates.SystemEnvironment do
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
  
  # Core system control logic
  def execute(%SystemEnvironment{initialization_status: nil}, %InitializeSystem{} = cmd) do
    %SystemInitialized{
      environment_id: UUID.uuid4(),
      initialized_at: DateTime.utc_now(),
      deployment_mode: cmd.deployment_mode,
      initial_parameters: cmd.parameters
    }
  end
  
  def execute(%SystemEnvironment{} = env, %UpdateSystemDate{} = cmd) do
    validate_date_change_authorization(env, cmd) 
    |> emit_event(%SystemDateChanged{
      old_date: env.system_date,
      new_date: cmd.new_date,
      changed_by: cmd.actor_id
    })
  end
end
```

### CompanyHierarchy aggregate

```elixir
defmodule Accountex.SystemManager.Aggregates.CompanyHierarchy do
  defstruct [
    :hierarchy_id,
    :companies,        # Map of company_id => Company struct
    :relationships,    # Parent-child relationships
    :consolidation_mappings,
    :shared_resources,
    :active_company_locks
  ]
  
  def execute(%CompanyHierarchy{} = hierarchy, %CreateCompany{} = cmd) do
    validate_unique_company_code(hierarchy, cmd.company_code)
    |> generate_company_database_schema(cmd)
    |> emit_event(%CompanyCreated{
      company_id: UUID.uuid4(),
      company_code: cmd.company_code,
      parent_id: cmd.parent_company_id,
      fiscal_calendar: cmd.fiscal_calendar,
      base_currency: cmd.base_currency
    })
  end
  
  def execute(%CompanyHierarchy{} = hierarchy, %LockCompany{} = cmd) do
    validate_no_active_users(hierarchy, cmd.company_id)
    |> emit_event(%CompanyLocked{
      company_id: cmd.company_id,
      lock_reason: cmd.reason,
      locked_until: cmd.until_timestamp
    })
  end
end
```

### UserManagement aggregate

```elixir
defmodule Accountex.SystemManager.Aggregates.UserManagement do
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
  
  def execute(%UserManagement{user_id: nil}, %CreateUser{} = cmd) do
    validate_password_policy(cmd.initial_password)
    |> generate_secure_credentials()
    |> emit_event(%UserCreated{
      user_id: UUID.uuid4(),
      username: cmd.username,
      initial_roles: cmd.roles,
      created_by: cmd.actor_id
    })
  end
  
  def execute(%UserManagement{} = user, %EnforcePasswordChange{} = cmd) do
    validate_password_complexity(cmd.new_password)
    |> check_password_history(user.password_history, cmd.new_password)
    |> emit_event(%PasswordChanged{
      user_id: user.user_id,
      change_reason: cmd.reason,
      expires_at: calculate_expiration(cmd.password_policy)
    })
  end
end
```

### ModuleRegistry aggregate

```elixir
defmodule Accountex.SystemManager.Aggregates.ModuleRegistry do
  defstruct [
    :registry_id,
    :registered_modules,
    :activation_status,
    :dependency_graph,
    :license_assignments,
    :module_health,
    :configuration_overrides
  ]
  
  def execute(%ModuleRegistry{} = registry, %ActivateModule{} = cmd) do
    validate_license_available(registry, cmd.module_name)
    |> check_dependencies_active(registry, cmd.module_name)
    |> load_module_code(cmd.module_name)
    |> emit_event(%ModuleActivated{
      module_name: cmd.module_name,
      activation_key: cmd.license_key,
      activated_by: cmd.actor_id,
      configuration: cmd.initial_config
    })
  end
end
```

## Commands and events for each major functionality

### System initialization and configuration

**Commands:**
- `InitializeSystem` - Bootstrap the Accountex environment
- `UpdateSystemConfiguration` - Modify global system parameters
- `SetSystemDate` - Change the system-wide operational date
- `ConfigureIntegrationEndpoint` - Setup external system connections
- `UpdatePerformanceParameters` - Adjust system performance settings

**Events:**
- `SystemInitialized` - System successfully bootstrapped
- `SystemConfigurationUpdated` - Global parameters changed
- `SystemDateChanged` - Operational date modified
- `IntegrationEndpointConfigured` - External connection established
- `PerformanceParametersUpdated` - Performance settings adjusted

### Company and database management

**Commands:**
- `CreateCompany` - Establish new legal entity/subsidiary
- `UpdateCompanySettings` - Modify company-specific configuration
- `LockCompany` - Prevent access during maintenance
- `UnlockCompany` - Restore company access
- `MapConsolidationAccounts` - Setup inter-company mappings
- `ShareResource` - Enable resource sharing between companies
- `InitiateCompanyArchive` - Begin company data archival

**Events:**
- `CompanyCreated` - New company established
- `CompanySettingsUpdated` - Configuration modified
- `CompanyLocked` - Access restricted
- `CompanyUnlocked` - Access restored
- `ConsolidationMappingCreated` - Account mapping established
- `ResourceShared` - Cross-company resource enabled
- `CompanyArchived` - Historical data moved to archive

### User and security management

**Commands:**
- `CreateUser` - Provision new user account
- `UpdateUserRoles` - Modify role assignments
- `EnforcePasswordChange` - Require password update
- `LockUserAccount` - Disable user access
- `CreateSecurityRole` - Define new role
- `SetFieldLevelSecurity` - Configure field access
- `TerminateUserSession` - Force user logout
- `GrantTemporaryAccess` - Time-limited permission elevation

**Events:**
- `UserCreated` - Account provisioned
- `UserRolesUpdated` - Permissions modified
- `PasswordChanged` - Credentials updated
- `UserAccountLocked` - Access disabled
- `SecurityRoleCreated` - New role defined
- `FieldSecurityConfigured` - Field access set
- `UserSessionTerminated` - Forced logout completed
- `TemporaryAccessGranted` - Elevated permissions active

### Module and license management

**Commands:**
- `RegisterModule` - Add module to registry
- `ActivateModule` - Enable module functionality
- `DeactivateModule` - Disable module
- `AssignModuleLicense` - Allocate license to module
- `RevokeLicense` - Remove license assignment
- `UpdateModuleConfiguration` - Modify module settings
- `CheckModuleHealth` - Verify module status

**Events:**
- `ModuleRegistered` - Module added to system
- `ModuleActivated` - Functionality enabled
- `ModuleDeactivated` - Functionality disabled
- `LicenseAssigned` - License allocated
- `LicenseRevoked` - License removed
- `ModuleConfigurationUpdated` - Settings changed
- `ModuleHealthChecked` - Status verified

### Fiscal period management

**Commands:**
- `CreateFiscalCalendar` - Define fiscal year structure
- `OpenAccountingPeriod` - Enable transaction posting
- `CloseAccountingPeriod` - Prevent further posting
- `CreateAdjustmentPeriod` - Setup special period (Period 13)
- `MapSubsidiaryPeriods` - Align subsidiary calendars
- `InitiatePeriodEndClose` - Begin closing process
- `ReopenClosedPeriod` - Allow retroactive adjustments

**Events:**
- `FiscalCalendarCreated` - Calendar defined
- `AccountingPeriodOpened` - Posting enabled
- `AccountingPeriodClosed` - Posting disabled
- `AdjustmentPeriodCreated` - Special period available
- `SubsidiaryPeriodsMapped` - Calendars aligned
- `PeriodEndCloseInitiated` - Closing started
- `ClosedPeriodReopened` - Retroactive posting allowed

### Audit and compliance

**Commands:**
- `ConfigureAuditPolicy` - Set audit requirements
- `GenerateComplianceReport` - Create regulatory report
- `ExportAuditTrail` - Extract audit data
- `ArchiveAuditData` - Move to long-term storage
- `ValidateDataIntegrity` - Check data consistency
- `InitiateSecurityAudit` - Begin security review

**Events:**
- `AuditPolicyConfigured` - Requirements set
- `ComplianceReportGenerated` - Report created
- `AuditTrailExported` - Data extracted
- `AuditDataArchived` - Moved to storage
- `DataIntegrityValidated` - Consistency verified
- `SecurityAuditInitiated` - Review started

## System Manager interactions with pluggable applications

### Service exposure patterns

The System Manager exposes core services through well-defined interfaces that other Accountex modules consume. Using Ash's domain boundaries and Commanded's event bus, the System Manager provides both synchronous service calls and asynchronous event notifications.

**Authentication service:**
```elixir
defmodule Accountex.SystemManager.Services.Authentication do
  use Ash.Domain
  
  def authenticate_user(credentials) do
    # Validate credentials against UserManagement aggregate
    # Generate session token with appropriate claims
    # Emit UserAuthenticated event for audit
  end
  
  def validate_session(token) do
    # Verify token validity and expiration
    # Check for security violations or locks
    # Return user context with permissions
  end
end
```

**Configuration service:**
```elixir
defmodule Accountex.SystemManager.Services.Configuration do
  def get_module_configuration(module_name, company_id) do
    # Retrieve base module configuration
    # Apply company-specific overrides
    # Apply user-specific preferences
    # Return merged configuration
  end
  
  def subscribe_to_configuration_changes(module_name, callback) do
    # Register module for configuration updates
    # Establish event subscription
    # Notify on relevant changes
  end
end
```

### Module discovery and registration

Modules implement the `Accountex.ModuleBehaviour` to participate in the system:

```elixir
defmodule Accountex.ModuleBehaviour do
  @callback module_info() :: %{
    name: String.t(),
    version: String.t(),
    dependencies: [String.t()],
    required_permissions: [String.t()],
    exposed_services: [atom()],
    event_subscriptions: [String.t()]
  }
  
  @callback initialize(config :: map()) :: {:ok, state} | {:error, reason}
  @callback health_check() :: {:healthy | :degraded | :unhealthy, details}
  @callback prepare_shutdown() :: :ok
end
```

### Dynamic availability handling

The System Manager implements circuit breaker patterns for graceful degradation when modules become unavailable:

```elixir
defmodule Accountex.SystemManager.ModuleProxy do
  use GenServer
  
  def call_module_function(module_name, function, args) do
    case check_module_availability(module_name) do
      :available ->
        execute_with_circuit_breaker(module_name, function, args)
      
      :unavailable ->
        handle_unavailable_module(module_name, function)
      
      :degraded ->
        execute_with_fallback(module_name, function, args)
    end
  end
  
  defp execute_with_circuit_breaker(module, function, args) do
    # Track success/failure rates
    # Open circuit on threshold breach
    # Implement exponential backoff
  end
end
```

## Security and access control business logic

### Multi-layered security model

The security architecture implements defense-in-depth with multiple authorization checkpoints:

**Company-level security:**
- Users assigned to specific companies
- Cross-company access requires explicit grants
- Company-specific security policies
- Segregation of sensitive company data

**Module-level security:**
- Role-based module access control
- Module-specific permission sets
- License-based feature availability
- Usage tracking for compliance

**Function-level security:**
- Granular operation permissions
- Transaction approval workflows
- Monetary limit enforcement
- Time-based access restrictions

**Field-level security:**
- Sensitive data masking
- Read-only field enforcement
- Audit trail for field changes
- PII protection compliance

### Authorization engine implementation

```elixir
defmodule Accountex.SystemManager.Authorization do
  use Ash.Policy.Authorizer
  
  def authorize(user, resource, action, context) do
    with :ok <- check_company_access(user, context.company_id),
         :ok <- check_module_access(user, resource.module),
         :ok <- check_role_permissions(user, action),
         :ok <- check_field_restrictions(user, resource, context.fields),
         :ok <- check_time_restrictions(user, action),
         :ok <- check_separation_of_duties(user, action, context) do
      {:ok, :authorized}
    else
      {:error, reason} -> 
        emit_security_violation(user, action, reason)
        {:error, :unauthorized}
    end
  end
end
```

### Fraud prevention patterns

The System Manager implements several fraud prevention mechanisms:

**Behavioral analytics:**
- Unusual login patterns detection
- Abnormal transaction velocity monitoring
- Geographic anomaly identification
- Access pattern deviation alerts

**Approval workflows:**
- Multi-level approval chains
- Segregation of duties enforcement
- Maker-checker patterns
- Escalation thresholds

**Session management:**
- Concurrent login prevention
- Idle timeout enforcement
- Forced re-authentication for sensitive operations
- Device fingerprinting

## Company and database management logic

### Multi-tenant architecture

The System Manager supports three multi-tenancy models with runtime selection:

**Shared database, separate schemas:**
```elixir
defmodule Accountex.SystemManager.TenantManager do
  def initialize_company_schema(company_id) do
    schema_name = "company_#{company_id}"
    
    # Create PostgreSQL schema
    Ecto.Adapters.SQL.query!(repo(), "CREATE SCHEMA #{schema_name}")
    
    # Run migrations in company schema
    Ecto.Migrator.run(repo(), migrations_path(), :up, 
      all: true, 
      prefix: schema_name
    )
    
    # Initialize base data
    seed_company_data(schema_name)
  end
  
  def with_company_context(company_id, fun) do
    schema = "company_#{company_id}"
    Ash.PlugHelpers.set_tenant(schema)
    fun.()
  end
end
```

**Shared database, shared schema:**
- Company ID filtering on all queries
- Row-level security policies
- Composite indexes including company_id
- Partition tables by company for performance

**Separate databases:**
- Database per company for complete isolation
- Connection pool management per database
- Cross-database queries for consolidation
- Centralized user authentication

### Inter-company transaction management

```elixir
defmodule Accountex.SystemManager.InterCompanyManager do
  def process_intercompany_transaction(transaction) do
    # Validate companies in same hierarchy
    validate_company_relationship(transaction)
    
    # Create reciprocal entries
    |> create_originating_entry(transaction.from_company)
    |> create_receiving_entry(transaction.to_company)
    
    # Mark for elimination in consolidation
    |> flag_for_consolidation_elimination()
    
    # Emit events for both companies
    |> emit_intercompany_events()
  end
end
```

## Module activation and licensing logic

### License management system

```elixir
defmodule Accountex.SystemManager.LicenseManager do
  defstruct [
    :license_pool,        # Available licenses by type
    :assignments,         # Current license assignments
    :usage_metrics,       # Usage tracking for compliance
    :restrictions,        # License limitations
    :expiration_dates     # License validity periods
  ]
  
  def assign_license(user_id, license_type, module) do
    with {:ok, available} <- check_license_availability(license_type),
         :ok <- validate_license_restrictions(license_type, user_id),
         :ok <- check_concurrent_usage(license_type) do
      
      consume_license(license_type)
      |> record_assignment(user_id, module)
      |> emit_license_assigned_event()
    end
  end
  
  def release_license(user_id, license_type) do
    return_to_pool(license_type)
    |> update_usage_metrics()
    |> emit_license_released_event()
  end
end
```

### Feature toggle implementation

```elixir
defmodule Accountex.SystemManager.FeatureFlags do
  use Jido.Agent,
    name: "feature_manager",
    description: "Manages feature availability across modules"
  
  def is_enabled?(feature, context) do
    cond do
      # Check license-based features
      license_enables_feature?(feature, context.licenses) -> true
      
      # Check company-specific overrides
      company_override?(feature, context.company_id) -> true
      
      # Check user-specific beta access
      user_in_beta?(feature, context.user_id) -> true
      
      # Check global feature flags
      globally_enabled?(feature) -> true
      
      # Default to disabled
      true -> false
    end
  end
end
```

## Fiscal period and accounting management

### Fiscal calendar engine

```elixir
defmodule Accountex.SystemManager.FiscalCalendar do
  defstruct [
    :calendar_id,
    :fiscal_year_start,
    :period_structure,    # :monthly, :quarterly, :custom
    :periods,            # List of period definitions
    :special_periods,    # Period 13, opening balance, etc.
    :current_period,
    :posting_restrictions
  ]
  
  def generate_fiscal_periods(calendar_config) do
    base_periods = generate_base_periods(calendar_config)
    
    # Add special periods if configured
    |> maybe_add_adjustment_period(calendar_config)
    |> maybe_add_opening_period(calendar_config)
    |> maybe_add_closing_period(calendar_config)
    
    # Set period statuses
    |> initialize_period_statuses()
  end
  
  def validate_posting_date(date, company_id) do
    calendar = get_company_calendar(company_id)
    period = find_period_for_date(calendar, date)
    
    case period.status do
      :open -> {:ok, period}
      :soft_closed -> check_retroactive_permission(period)
      :hard_closed -> {:error, :period_closed}
      :not_opened -> {:error, :future_period}
    end
  end
end
```

### Period-end closing orchestration

```elixir
defmodule Accountex.SystemManager.ProcessManagers.PeriodEndClose do
  use Commanded.ProcessManager,
    application: Accountex.App,
    name: "PeriodEndClose"
  
  defstruct [
    :close_id,
    :company_id,
    :period_id,
    :checklist_items,
    :completion_status,
    :validation_errors
  ]
  
  def handle(%{} = pm, %PeriodCloseInitiated{} = event) do
    pm
    |> initialize_checklist()
    |> validate_all_modules_ready()
    |> run_pre_close_validations()
    |> execute_close_sequence()
  end
  
  defp execute_close_sequence(pm) do
    pm
    |> close_subledger_modules()  # AP, AR, Inventory
    |> post_to_general_ledger()
    |> calculate_period_balances()
    |> generate_financial_statements()
    |> lock_period_for_posting()
    |> emit_period_closed_event()
  end
end
```

## User and group management with permissions

### Hierarchical group structure

```elixir
defmodule Accountex.SystemManager.GroupHierarchy do
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
  
  def calculate_effective_permissions(user_id) do
    direct_roles = get_user_direct_roles(user_id)
    group_roles = get_user_group_roles(user_id)
    inherited_roles = get_inherited_roles(user_id)
    
    # Merge permissions with conflict resolution
    merge_permissions([direct_roles, group_roles, inherited_roles])
    |> apply_restrictions(user_id)
    |> apply_separation_of_duties()
  end
end
```

### Advanced password policy engine

```elixir
defmodule Accountex.SystemManager.PasswordPolicy do
  use Jido.Agent,
    name: "password_enforcer",
    description: "Enforces SOX-compliant password policies"
  
  def validate_password(password, user, policy) do
    with :ok <- check_minimum_length(password, policy.min_length),
         :ok <- check_complexity(password, policy.complexity_rules),
         :ok <- check_dictionary_words(password),
         :ok <- check_user_info_similarity(password, user),
         :ok <- check_password_history(password, user.password_history),
         :ok <- check_breach_database(password) do
      {:ok, calculate_password_strength(password)}
    end
  end
  
  def enforce_rotation_policy(user) do
    days_since_change = Date.diff(Date.utc_today(), user.last_password_change)
    
    cond do
      days_since_change > 90 -> force_password_change(user)
      days_since_change > 75 -> send_expiration_warning(user)
      true -> :ok
    end
  end
end
```

## Audit trail functionality

### Comprehensive audit framework

```elixir
defmodule Accountex.SystemManager.AuditTrail do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]
  
  attributes do
    uuid_primary_key :audit_id
    attribute :entity_type, :string
    attribute :entity_id, :uuid
    attribute :action, :atom
    attribute :actor_id, :uuid
    attribute :actor_type, :atom  # :user, :system, :agent
    attribute :before_state, :map
    attribute :after_state, :map
    attribute :change_delta, :map
    attribute :metadata, :map
    attribute :ip_address, :string
    attribute :user_agent, :string
    attribute :session_id, :uuid
    attribute :company_id, :uuid
    attribute :occurred_at, :utc_datetime_usec
    attribute :risk_score, :integer
  end
  
  calculations do
    calculate :data_classification, :atom do
      # Classify data sensitivity for compliance
      classify_data_sensitivity(before_state, after_state)
    end
  end
end
```

### Audit analysis engine

```elixir
defmodule Accountex.SystemManager.AuditAnalyzer do
  use Jido.Agent,
    name: "audit_analyzer",
    description: "Performs real-time audit analysis and anomaly detection"
  
  def analyze_audit_stream do
    # Subscribe to audit event stream
    EventStore.subscribe_to_stream("$ce-AuditTrail", self())
    
    # Perform continuous analysis
    detect_unusual_patterns()
    |> identify_high_risk_activities()
    |> check_compliance_violations()
    |> generate_alerts()
  end
  
  defp detect_unusual_patterns do
    # Machine learning models for anomaly detection
    # Statistical analysis of access patterns
    # Behavioral baseline comparison
  end
end
```

## Data management and maintenance operations

### Intelligent archival system

```elixir
defmodule Accountex.SystemManager.DataArchiver do
  use Jido.Agent,
    name: "data_archiver",
    description: "Manages data lifecycle and archival operations"
  
  def execute_archival_policy(company_id, policy) do
    identify_archivable_data(company_id, policy)
    |> validate_retention_requirements()
    |> create_archive_snapshot()
    |> move_to_archive_storage()
    |> update_data_catalog()
    |> verify_archive_integrity()
    |> cleanup_source_data()
  end
  
  defp identify_archivable_data(company_id, policy) do
    # Query for data meeting archival criteria
    # Check transaction completion status
    # Verify audit trail requirements
    # Ensure no active references
  end
  
  defp move_to_archive_storage(data) do
    # Compress data for storage efficiency
    # Encrypt sensitive information
    # Transfer to cost-optimized storage tier
    # Maintain searchable metadata index
  end
end
```

### Database maintenance orchestrator

```elixir
defmodule Accountex.SystemManager.MaintenanceOrchestrator do
  use GenServer
  
  def schedule_maintenance_window(task, timing_preferences) do
    identify_low_activity_period(timing_preferences)
    |> notify_affected_users()
    |> initiate_maintenance_mode()
    |> execute_maintenance_task(task)
    |> verify_system_integrity()
    |> restore_normal_operations()
  end
  
  defp execute_maintenance_task(task) do
    case task.type do
      :index_rebuild -> rebuild_database_indexes()
      :statistics_update -> update_query_statistics()
      :data_purge -> purge_expired_data()
      :backup_verification -> verify_backup_integrity()
      :performance_tuning -> optimize_query_plans()
    end
  end
end
```

### Data integrity monitoring

```elixir
defmodule Accountex.SystemManager.IntegrityMonitor do
  use Jido.Agent,
    name: "integrity_monitor",
    description: "Continuously monitors data integrity across the system"
  
  def perform_integrity_checks do
    schedule_checks()
    |> verify_referential_integrity()
    |> check_financial_balances()
    |> validate_audit_trail_continuity()
    |> detect_orphaned_records()
    |> verify_document_attachments()
    |> generate_integrity_report()
  end
  
  defp verify_financial_balances do
    # Ensure debits equal credits
    # Validate subsidiary ledger reconciliation
    # Check inter-company eliminations
    # Verify period-end balances
  end
end
```

## Implementation considerations

### Event store optimization

The System Manager implements partitioned event streams for scalability:

```elixir
defmodule Accountex.SystemManager.EventStore do
  def partition_strategy(event) do
    case event do
      %{company_id: company_id} -> "company-#{company_id}"
      %{module: module} -> "module-#{module}"
      %{aggregate_id: id} -> "aggregate-#{String.slice(id, 0..1)}"
      _ -> "system-general"
    end
  end
  
  def configure_retention(stream_category) do
    case stream_category do
      "audit-" <> _ -> {:years, 7}  # Compliance requirement
      "company-" <> _ -> {:years, 3}
      "session-" <> _ -> {:days, 90}
      _ -> {:years, 1}
    end
  end
end
```

### Performance optimization strategies

**Caching layers:**
- User permission cache with TTL
- Module configuration cache
- Company hierarchy cache
- Frequently accessed parameters

**Async processing:**
- Audit trail writes via GenStage
- Report generation in background
- Maintenance operations queued
- Event projections built asynchronously

**Resource pooling:**
- Database connection pools per company
- License pool management
- Worker pool for batch operations
- Circuit breakers for external services

### Deployment architecture

The System Manager deploys as a core OTP application within the Accountex umbrella:

```elixir
# apps/accountex_system_manager/mix.exs
defmodule Accountex.SystemManager.MixProject do
  use Mix.Project
  
  def application do
    [
      mod: {Accountex.SystemManager.Application, []},
      extra_applications: [:logger, :runtime_tools],
      included_applications: [:ash, :commanded, :jido]
    ]
  end
  
  def deps do
    [
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:commanded, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:jido, "~> 0.1"},
      {:libcluster, "~> 3.3"},
      {:telemetry, "~> 1.0"}
    ]
  end
end
```

This comprehensive business logic design provides Accountex with enterprise-grade system management capabilities while leveraging Elixir's strengths in concurrent processing, fault tolerance, and distributed systems. The event-sourced architecture ensures complete auditability, the modular design supports extensibility, and the multi-tenant capabilities enable SaaS deployment models.
