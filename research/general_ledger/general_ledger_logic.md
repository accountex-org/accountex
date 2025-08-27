# General Ledger Business Logic Document

## Executive Summary

The General Ledger (GL) module serves as the central accounting hub for Accountex, managing the chart of accounts, journal entries, and financial reporting. Built on event-sourced architecture using Elixir, Ash framework, Jido for agentic capabilities, and Commanded/AshCommanded for event sourcing, this module maintains strict double-entry bookkeeping principles while providing real-time financial insights. The GL module operates as an autonomous service that can function independently or integrate seamlessly with other Accountex modules when available.

## Domain Overview and Bounded Context

The General Ledger domain encompasses all core accounting functionality required for maintaining accurate financial records. This bounded context includes chart of accounts management, journal entry processing, period management, trial balance generation, and financial reporting capabilities. The domain maintains strict consistency boundaries around journal entries to ensure accounting integrity while allowing eventual consistency for reporting projections. Integration points with sub-ledgers like Accounts Payable, Accounts Receivable, Inventory, and Sales Orders are handled through domain events, allowing the GL to function independently when these modules are unavailable.

## Commands and Their Business Logic

### Account Management Commands

```elixir
defmodule Accountex.GL.Commands.CreateAccount do
  @moduledoc """
  Command to create a new GL account
  
  ## Business Rules
  - Account code must be unique within the chart of accounts
  - Account type must align with hierarchical position
  - Parent accounts cannot have direct transactions
  - System accounts cannot be modified after setup
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :account_code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :account_type, :atom,
      constraints: [one_of: [:asset, :liability, :equity, :revenue, :expense]]
    attribute :normal_balance, :atom,
      constraints: [one_of: [:debit, :credit]]
    attribute :parent_account_id, Ash.Type.UUID
    attribute :currency_code, :string, default: "USD"
    attribute :status, :atom, default: :active
    attribute :is_header_account, :boolean, default: false
    attribute :is_system_account, :boolean, default: false
    attribute :metadata, :map, default: %{}
  end
  
  validations do
    validate present([:account_code, :name, :account_type, :normal_balance])
    validate {Accountex.GL.Validators.UniqueAccountCode, 
      attribute: :account_code,
      scope: :organization_id}
    validate {Accountex.GL.Validators.AccountHierarchy,
      attributes: [:account_type, :parent_account_id]}
  end
end

defmodule Accountex.GL.Commands.ModifyAccount do
  @moduledoc """
  Command to modify an existing GL account
  
  ## Business Rules
  - Cannot change fundamental properties like account type or code
  - No posted transactions can exist for accounts being deactivated
  - Hierarchy changes must maintain logical consistency
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :name, :string
    attribute :description, :string
    attribute :status, :atom
    attribute :parent_account_id, Ash.Type.UUID
    attribute :modified_by, Ash.Type.UUID, allow_nil?: false
    attribute :modification_reason, :string
  end
  
  validations do
    validate {Accountex.GL.Validators.ModificationAllowed,
      attribute: :account_id}
    validate {Accountex.GL.Validators.NoPostedTransactions,
      attribute: :account_id,
      when: [status: :inactive]}
  end
end

defmodule Accountex.GL.Commands.DeactivateAccount do
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :deactivation_reason, :string, allow_nil?: false
    attribute :cascade_to_children, :boolean, default: false
    attribute :effective_date, :date, allow_nil?: false
    attribute :authorized_by, Ash.Type.UUID, allow_nil?: false
  end
  
  validations do
    validate {Accountex.GL.Validators.AccountDeactivation,
      attributes: [:account_id, :cascade_to_children]}
  end
end
```

### Journal Entry Commands

```elixir
defmodule Accountex.GL.Commands.CreateJournalEntry do
  @moduledoc """
  Command to create a new journal entry
  
  ## Business Rules
  - Total debits must equal total credits
  - Each line must reference a valid, active account
  - Posting dates must fall within open fiscal periods
  - Unique transaction reference required for audit
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :journal_date, :date, allow_nil?: false
    attribute :posting_date, :date, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :reference_number, :string
    attribute :journal_type, :atom,
      constraints: [one_of: [:manual, :automatic, :recurring, :reversing]]
    attribute :source_module, :atom
    attribute :source_document_id, Ash.Type.UUID
    
    attribute :lines, {:array, :map}, allow_nil?: false do
      constraints items: [
        fields: [
          account_id: [type: Ash.Type.UUID, allow_nil?: false],
          debit_amount: [type: :decimal],
          credit_amount: [type: :decimal],
          description: [type: :string],
          cost_center: [type: :string],
          project_code: [type: :string],
          dimensions: [type: :map]
        ]
      ]
    end
    
    attribute :status, :atom, default: :draft
    attribute :created_by, Ash.Type.UUID, allow_nil?: false
    attribute :metadata, :map, default: %{}
  end
  
  validations do
    validate {Accountex.GL.Validators.BalancedEntry,
      attribute: :lines}
    validate {Accountex.GL.Validators.ValidPeriod,
      attributes: [:posting_date]}
    validate {Accountex.GL.Validators.AccountsActive,
      attribute: :lines}
  end
end

defmodule Accountex.GL.Commands.PostJournalEntry do
  @moduledoc """
  Command to post a draft journal entry
  
  ## Business Rules
  - Final validation of account statuses and period locks
  - Balance equation must be satisfied
  - Posted entries become immutable
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :journal_entry_id, Ash.Type.UUID, allow_nil?: false
    attribute :posting_user, Ash.Type.UUID, allow_nil?: false
    attribute :posting_timestamp, :utc_datetime, allow_nil?: false
    attribute :approval_reference, :string
    attribute :force_post, :boolean, default: false
  end
  
  validations do
    validate {Accountex.GL.Validators.PostingAllowed,
      attributes: [:journal_entry_id, :force_post]}
  end
end

defmodule Accountex.GL.Commands.ReverseJournalEntry do
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :original_entry_id, Ash.Type.UUID, allow_nil?: false
    attribute :reversal_date, :date, allow_nil?: false
    attribute :reversal_reason, :string, allow_nil?: false
    attribute :auto_post, :boolean, default: false
    attribute :authorized_by, Ash.Type.UUID, allow_nil?: false
  end
  
  validations do
    validate {Accountex.GL.Validators.ReversalAllowed,
      attribute: :original_entry_id}
    validate {Accountex.GL.Validators.ValidPeriod,
      attributes: [:reversal_date]}
  end
end

defmodule Accountex.GL.Commands.CreateRecurringEntry do
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :template_name, :string, allow_nil?: false
    attribute :recurrence_pattern, :atom,
      constraints: [one_of: [:daily, :weekly, :monthly, :quarterly, :yearly]]
    attribute :start_date, :date, allow_nil?: false
    attribute :end_date, :date
    attribute :auto_post, :boolean, default: false
    attribute :journal_lines, {:array, :map}, allow_nil?: false
    attribute :notification_recipients, {:array, :string}, default: []
  end
end
```

### Period Management Commands

```elixir
defmodule Accountex.GL.Commands.OpenFiscalPeriod do
  @moduledoc """
  Command to open a new fiscal period
  
  ## Business Rules
  - Periods must open in sequential order
  - Prior periods must be properly closed or remain open per config
  - Period-specific projections initialized
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :period_number, :integer, allow_nil?: false
    attribute :fiscal_year, :integer, allow_nil?: false
    attribute :start_date, :date, allow_nil?: false
    attribute :end_date, :date, allow_nil?: false
    attribute :period_type, :atom,
      constraints: [one_of: [:regular, :adjustment, :year_end]]
    attribute :opened_by, Ash.Type.UUID, allow_nil?: false
  end
  
  validations do
    validate {Accountex.GL.Validators.SequentialPeriod,
      attributes: [:period_number, :fiscal_year]}
    validate {Accountex.GL.Validators.DateRangeValid,
      attributes: [:start_date, :end_date]}
  end
end

defmodule Accountex.GL.Commands.CloseFiscalPeriod do
  @moduledoc """
  Command to close a fiscal period
  
  ## Business Rules
  - Executes closing checklist validations
  - Sub-ledger reconciliation required
  - Generates period snapshots for reporting
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :period_id, Ash.Type.UUID, allow_nil?: false
    attribute :closing_type, :atom,
      constraints: [one_of: [:soft_close, :hard_close]]
    attribute :reconciliation_status, :map, allow_nil?: false
    attribute :adjustment_entries, {:array, Ash.Type.UUID}, default: []
    attribute :closed_by, Ash.Type.UUID, allow_nil?: false
    attribute :closing_notes, :string
  end
  
  validations do
    validate {Accountex.GL.Validators.ClosingChecklist,
      attributes: [:period_id, :reconciliation_status]}
  end
end

defmodule Accountex.GL.Commands.ExecuteYearEndClose do
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :fiscal_year, :integer, allow_nil?: false
    attribute :closing_entries, {:array, :map}, allow_nil?: false
    attribute :retained_earnings_account_id, Ash.Type.UUID, allow_nil?: false
    attribute :tax_provisions, :map, default: %{}
    attribute :carry_forward_rules, :map, default: %{}
    attribute :executed_by, Ash.Type.UUID, allow_nil?: false
  end
end
```

## Events and Event Handlers

### Core Accounting Events

```elixir
defmodule Accountex.GL.Events.AccountCreated do
  @moduledoc """
  Event emitted when a GL account is created
  
  ## Downstream Effects
  - Updates chart of accounts projection
  - Initializes account balance records
  - Notifies integrated modules
  """
  
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :account_code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :account_type, :atom
    attribute :normal_balance, :atom
    attribute :parent_account_id, Ash.Type.UUID
    attribute :currency_code, :string
    attribute :created_at, :utc_datetime, default: &DateTime.utc_now/0
    attribute :created_by, Ash.Type.UUID
    attribute :metadata, :map
  end
end

defmodule Accountex.GL.Events.JournalEntryPosted do
  @moduledoc """
  Event emitted when a journal entry is posted
  
  ## Downstream Effects
  - Updates account balances
  - Updates transaction history
  - Publishes to system event bus
  """
  
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :journal_entry_id, Ash.Type.UUID, allow_nil?: false
    attribute :posting_date, :date, allow_nil?: false
    attribute :journal_lines, {:array, :map}, allow_nil?: false
    attribute :total_debits, :decimal, allow_nil?: false
    attribute :total_credits, :decimal, allow_nil?: false
    attribute :posted_by, Ash.Type.UUID
    attribute :posted_at, :utc_datetime, default: &DateTime.utc_now/0
    attribute :source_module, :atom
    attribute :source_document_id, Ash.Type.UUID
  end
end

defmodule Accountex.GL.Events.AccountBalanceUpdated do
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :previous_balance, :decimal, allow_nil?: false
    attribute :transaction_amount, :decimal, allow_nil?: false
    attribute :new_balance, :decimal, allow_nil?: false
    attribute :balance_type, :atom # :debit or :credit
    attribute :journal_entry_id, Ash.Type.UUID
    attribute :updated_at, :utc_datetime, default: &DateTime.utc_now/0
  end
end

defmodule Accountex.GL.Events.PeriodClosed do
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :period_id, Ash.Type.UUID, allow_nil?: false
    attribute :fiscal_year, :integer
    attribute :period_number, :integer
    attribute :closing_type, :atom
    attribute :trial_balance, :map
    attribute :closing_entries, {:array, Ash.Type.UUID}
    attribute :closed_at, :utc_datetime, default: &DateTime.utc_now/0
    attribute :closed_by, Ash.Type.UUID
  end
end
```

### Integration Events

```elixir
defmodule Accountex.GL.Events.SubLedgerTransactionReceived do
  @moduledoc """
  Event for processing journal entries from integrated modules
  
  ## Processing Rules
  - Validates entry against GL rules
  - Auto-posts if configured
  - Generates rejection events for failures
  """
  
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :source_module, :atom, allow_nil?: false
    attribute :transaction_id, Ash.Type.UUID, allow_nil?: false
    attribute :transaction_type, :atom
    attribute :journal_lines, {:array, :map}, allow_nil?: false
    attribute :posting_date, :date
    attribute :auto_post, :boolean, default: false
    attribute :reference_data, :map
    attribute :received_at, :utc_datetime, default: &DateTime.utc_now/0
  end
end

defmodule Accountex.GL.Events.InterCompanyTransactionInitiated do
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :transaction_id, Ash.Type.UUID, allow_nil?: false
    attribute :source_company_id, Ash.Type.UUID
    attribute :target_company_id, Ash.Type.UUID
    attribute :elimination_entries, {:array, :map}
    attribute :initiated_at, :utc_datetime, default: &DateTime.utc_now/0
  end
end
```

### Event Handlers

```elixir
defmodule Accountex.GL.EventHandlers.JournalEntryHandler do
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "GLJournalEntryHandler"

  alias Accountex.GL.Events.{JournalEntryPosted, AccountBalanceUpdated}
  alias Accountex.GL.Projections
  
  def handle(%JournalEntryPosted{} = event, _metadata) do
    # Update multiple projections simultaneously
    update_account_balances(event)
    update_transaction_history(event)
    update_period_totals(event)
    publish_to_event_bus(event)
    
    # Trigger Jido agents for dependent workflows
    Accountex.Agents.GLMonitor.analyze_posting(event)
    
    :ok
  end
  
  def handle(%AccountBalanceUpdated{} = event, _metadata) do
    # Update real-time balance projections
    Projections.AccountBalance
    |> Ash.Changeset.for_update(:update_balance, %{
      account_id: event.account_id,
      new_balance: event.new_balance,
      last_transaction_id: event.journal_entry_id,
      updated_at: event.updated_at
    })
    |> Accountex.Repo.update!()
    
    :ok
  end
  
  defp update_account_balances(%JournalEntryPosted{} = event) do
    Enum.each(event.journal_lines, fn line ->
      account = get_account!(line.account_id)
      
      previous_balance = account.current_balance
      transaction_amount = line.debit_amount || Decimal.negate(line.credit_amount || Decimal.new(0))
      new_balance = Decimal.add(previous_balance, transaction_amount)
      
      dispatch_event(%AccountBalanceUpdated{
        account_id: line.account_id,
        previous_balance: previous_balance,
        transaction_amount: transaction_amount,
        new_balance: new_balance,
        journal_entry_id: event.journal_entry_id
      })
    end)
  end
  
  defp publish_to_event_bus(event) do
    Phoenix.PubSub.broadcast(
      Accountex.PubSub,
      "gl_events",
      {:journal_posted, event}
    )
  end
end

defmodule Accountex.GL.EventHandlers.SubLedgerHandler do
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "GLSubLedgerHandler"
    
  alias Accountex.GL.Events.SubLedgerTransactionReceived
  
  def handle(%SubLedgerTransactionReceived{} = event, _metadata) do
    case validate_subledger_entry(event) do
      {:ok, validated_entry} ->
        create_and_post_journal_entry(validated_entry, event)
      {:error, validation_errors} ->
        dispatch_rejection_event(event, validation_errors)
    end
    
    :ok
  end
  
  defp validate_subledger_entry(event) do
    with :ok <- validate_accounts_exist(event.journal_lines),
         :ok <- validate_balanced(event.journal_lines),
         :ok <- validate_period_open(event.posting_date) do
      {:ok, event}
    end
  end
  
  defp create_and_post_journal_entry(validated_entry, original_event) do
    journal_entry = %Accountex.GL.Commands.CreateJournalEntry{
      journal_date: Date.utc_today(),
      posting_date: validated_entry.posting_date,
      description: build_description(original_event),
      journal_type: :automatic,
      source_module: original_event.source_module,
      source_document_id: original_event.transaction_id,
      lines: validated_entry.journal_lines,
      status: if(original_event.auto_post, do: :posted, else: :draft)
    }
    
    Accountex.GL.dispatch_command(journal_entry)
  end
end
```

## Aggregates and Their Invariants

### Account Aggregate

```elixir
defmodule Accountex.GL.Aggregates.Account do
  @moduledoc """
  Account Aggregate - maintains chart of accounts integrity
  
  ## Invariants
  - Account codes must be unique within a company
  - Parent-child relationships must form valid trees
  - Account types must be consistent with hierarchy
  - System accounts remain immutable
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate, AshEvents.Events]
  
  commanded_aggregate do
    identity :account_id
    
    command CreateAccount do
      handler &__MODULE__.handle_create_account/2
    end
    
    command ModifyAccount do
      handler &__MODULE__.handle_modify_account/2
    end
    
    command DeactivateAccount do
      handler &__MODULE__.handle_deactivate_account/2
    end
  end
  
  attributes do
    uuid_primary_key :account_id
    attribute :account_code, :string
    attribute :name, :string
    attribute :account_type, :atom
    attribute :normal_balance, :atom
    attribute :parent_account_id, Ash.Type.UUID
    attribute :is_header_account, :boolean
    attribute :is_system_account, :boolean
    attribute :status, :atom
    attribute :balance, :decimal, default: Decimal.new(0)
    attribute :children, {:array, Ash.Type.UUID}, default: []
  end
  
  def handle_create_account(nil, %CreateAccount{} = cmd) do
    if account_code_exists?(cmd.account_code) do
      {:error, :duplicate_account_code}
    else
      %AccountCreated{
        account_id: cmd.id,
        account_code: cmd.account_code,
        name: cmd.name,
        account_type: cmd.account_type,
        normal_balance: cmd.normal_balance,
        parent_account_id: cmd.parent_account_id,
        is_header_account: cmd.is_header_account,
        is_system_account: cmd.is_system_account,
        currency_code: cmd.currency_code
      }
    end
  end
  
  def handle_modify_account(%{is_system_account: true}, _cmd) do
    {:error, :cannot_modify_system_account}
  end
  
  def handle_modify_account(state, %ModifyAccount{} = cmd) do
    cond do
      has_posted_transactions?(state.account_id) && changing_fundamental_properties?(cmd) ->
        {:error, :cannot_change_with_transactions}
      
      !valid_hierarchy_change?(state, cmd.parent_account_id) ->
        {:error, :invalid_hierarchy}
      
      true ->
        %AccountModified{
          account_id: state.account_id,
          changes: extract_changes(state, cmd),
          modified_by: cmd.modified_by,
          modification_reason: cmd.modification_reason
        }
    end
  end
  
  def handle_deactivate_account(state, %DeactivateAccount{} = cmd) do
    cond do
      state.is_system_account ->
        {:error, :cannot_deactivate_system_account}
      
      has_non_zero_balance?(state) ->
        {:error, :account_has_balance}
      
      has_active_children?(state) && !cmd.cascade_to_children ->
        {:error, :has_active_children}
      
      true ->
        %AccountDeactivated{
          account_id: state.account_id,
          effective_date: cmd.effective_date,
          deactivation_reason: cmd.deactivation_reason,
          cascade_to_children: cmd.cascade_to_children
        }
    end
  end
  
  # State evolution from events
  def apply(state, %AccountCreated{} = event) do
    %__MODULE__{
      account_id: event.account_id,
      account_code: event.account_code,
      name: event.name,
      account_type: event.account_type,
      normal_balance: event.normal_balance,
      parent_account_id: event.parent_account_id,
      is_header_account: event.is_header_account,
      is_system_account: event.is_system_account,
      status: :active,
      balance: Decimal.new(0)
    }
  end
  
  def apply(state, %AccountModified{} = event) do
    Enum.reduce(event.changes, state, fn {field, value}, acc ->
      Map.put(acc, field, value)
    end)
  end
  
  def apply(state, %AccountDeactivated{} = event) do
    %{state | status: :inactive}
  end
end
```

### Journal Entry Aggregate

```elixir
defmodule Accountex.GL.Aggregates.JournalEntry do
  @moduledoc """
  Journal Entry Aggregate - enforces double-entry bookkeeping
  
  ## Invariants
  - Debits must equal credits
  - All referenced accounts must exist and be active
  - Posted entries become immutable
  - Posting dates must fall within open periods
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate]
  
  commanded_aggregate do
    identity :journal_entry_id
    
    command CreateJournalEntry do
      handler &__MODULE__.handle_create/2
    end
    
    command PostJournalEntry do
      handler &__MODULE__.handle_post/2
    end
    
    command ReverseJournalEntry do
      handler &__MODULE__.handle_reverse/2
    end
  end
  
  attributes do
    uuid_primary_key :journal_entry_id
    attribute :reference_number, :string
    attribute :journal_date, :date
    attribute :posting_date, :date
    attribute :description, :string
    attribute :journal_type, :atom
    attribute :status, :atom, default: :draft
    attribute :lines, {:array, :map}
    attribute :total_debits, :decimal
    attribute :total_credits, :decimal
    attribute :posted_at, :utc_datetime
    attribute :posted_by, Ash.Type.UUID
    attribute :reversed, :boolean, default: false
    attribute :reversal_of, Ash.Type.UUID
  end
  
  def handle_create(nil, %CreateJournalEntry{} = cmd) do
    with :ok <- validate_balanced(cmd.lines),
         :ok <- validate_accounts_active(cmd.lines),
         :ok <- validate_posting_period(cmd.posting_date) do
      
      totals = calculate_totals(cmd.lines)
      
      %JournalEntryCreated{
        journal_entry_id: cmd.id,
        reference_number: generate_reference_number(),
        journal_date: cmd.journal_date,
        posting_date: cmd.posting_date,
        description: cmd.description,
        journal_type: cmd.journal_type,
        lines: cmd.lines,
        total_debits: totals.debits,
        total_credits: totals.credits,
        created_by: cmd.created_by
      }
    end
  end
  
  def handle_post(%{status: :posted}, _cmd) do
    {:error, :already_posted}
  end
  
  def handle_post(state, %PostJournalEntry{} = cmd) do
    with :ok <- final_validation(state),
         :ok <- check_period_still_open(state.posting_date) do
      
      %JournalEntryPosted{
        journal_entry_id: state.journal_entry_id,
        posting_date: state.posting_date,
        journal_lines: state.lines,
        total_debits: state.total_debits,
        total_credits: state.total_credits,
        posted_by: cmd.posting_user,
        posted_at: cmd.posting_timestamp,
        source_module: state.source_module,
        source_document_id: state.source_document_id
      }
    end
  end
  
  def handle_reverse(%{status: :draft}, _cmd) do
    {:error, :cannot_reverse_draft}
  end
  
  def handle_reverse(%{reversed: true}, _cmd) do
    {:error, :already_reversed}
  end
  
  def handle_reverse(state, %ReverseJournalEntry{} = cmd) do
    reversed_lines = Enum.map(state.lines, fn line ->
      %{line | 
        debit_amount: line.credit_amount,
        credit_amount: line.debit_amount,
        description: "Reversal: #{line.description}"
      }
    end)
    
    %JournalEntryReversed{
      original_entry_id: state.journal_entry_id,
      reversal_entry_id: UUID.uuid4(),
      reversal_date: cmd.reversal_date,
      reversal_lines: reversed_lines,
      reversal_reason: cmd.reversal_reason,
      authorized_by: cmd.authorized_by,
      auto_post: cmd.auto_post
    }
  end
  
  defp validate_balanced(lines) do
    totals = calculate_totals(lines)
    
    if Decimal.compare(totals.debits, totals.credits) == :eq do
      :ok
    else
      {:error, :unbalanced_entry}
    end
  end
  
  defp calculate_totals(lines) do
    Enum.reduce(lines, %{debits: Decimal.new(0), credits: Decimal.new(0)}, fn line, acc ->
      %{
        debits: Decimal.add(acc.debits, line.debit_amount || Decimal.new(0)),
        credits: Decimal.add(acc.credits, line.credit_amount || Decimal.new(0))
      }
    end)
  end
end
```

### Fiscal Period Aggregate

```elixir
defmodule Accountex.GL.Aggregates.FiscalPeriod do
  @moduledoc """
  Fiscal Period Aggregate - manages temporal boundaries
  
  ## Invariants
  - Periods must follow sequential progression
  - Only one period can be current
  - Closed periods reject new transactions
  - Year-end requires all monthly periods closed
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate]
  
  commanded_aggregate do
    identity :period_id
    
    command OpenFiscalPeriod do
      handler &__MODULE__.handle_open/2
    end
    
    command CloseFiscalPeriod do
      handler &__MODULE__.handle_close/2
    end
    
    command ReopenPeriod do
      handler &__MODULE__.handle_reopen/2
    end
  end
  
  attributes do
    uuid_primary_key :period_id
    attribute :period_number, :integer
    attribute :fiscal_year, :integer
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :status, :atom, default: :closed
    attribute :period_type, :atom
    attribute :closing_entries, {:array, Ash.Type.UUID}, default: []
    attribute :trial_balance_snapshot, :map
  end
  
  def handle_open(nil, %OpenFiscalPeriod{} = cmd) do
    with :ok <- validate_sequential(cmd),
         :ok <- validate_no_overlap(cmd) do
      
      %PeriodOpened{
        period_id: cmd.id,
        period_number: cmd.period_number,
        fiscal_year: cmd.fiscal_year,
        start_date: cmd.start_date,
        end_date: cmd.end_date,
        period_type: cmd.period_type,
        opened_by: cmd.opened_by
      }
    end
  end
  
  def handle_close(%{status: :closed}, _cmd) do
    {:error, :already_closed}
  end
  
  def handle_close(state, %CloseFiscalPeriod{} = cmd) do
    with :ok <- run_closing_checklist(state),
         {:ok, trial_balance} <- generate_trial_balance(state),
         :ok <- validate_balanced_period(trial_balance) do
      
      %PeriodClosed{
        period_id: state.period_id,
        fiscal_year: state.fiscal_year,
        period_number: state.period_number,
        closing_type: cmd.closing_type,
        trial_balance: trial_balance,
        closing_entries: cmd.adjustment_entries,
        closed_by: cmd.closed_by
      }
    end
  end
  
  defp run_closing_checklist(period) do
    checklist = [
      {:verify_all_transactions_posted, verify_transactions_posted(period)},
      {:reconcile_subledgers, reconcile_subledgers(period)},
      {:validate_account_balances, validate_balances(period)},
      {:check_intercompany_balances, check_intercompany(period)}
    ]
    
    case Enum.find(checklist, fn {_step, result} -> result != :ok end) do
      nil -> :ok
      {step, error} -> {:error, {step, error}}
    end
  end
end
```

## Read Models and Projections

### Chart of Accounts Projection

```elixir
defmodule Accountex.GL.Projections.ChartOfAccounts do
  @moduledoc """
  Hierarchical account structure optimized for tree traversal
  
  ## Purpose
  - Fast account lookup and validation
  - Hierarchical navigation
  - Account filtering for transaction entry
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]
  
  postgres do
    table "gl_chart_of_accounts"
    repo Accountex.Repo
    
    custom_indexes do
      index [:account_code], unique: true
      index [:parent_account_id]
      index [:account_type, :status]
    end
  end
  
  attributes do
    uuid_primary_key :id
    attribute :account_code, :string, allow_nil?: false
    attribute :name, :string
    attribute :account_type, :atom
    attribute :normal_balance, :atom
    attribute :parent_account_id, Ash.Type.UUID
    attribute :path, {:array, :string}, default: []  # Materialized path
    attribute :depth, :integer, default: 0
    attribute :is_header_account, :boolean
    attribute :is_system_account, :boolean
    attribute :status, :atom
    attribute :child_count, :integer, default: 0
    attribute :last_transaction_date, :date
    attribute :updated_at, :utc_datetime
  end
  
  calculations do
    calculate :full_path, :string do
      expr(fragment("array_to_string(?, ' > ')", path))
    end
    
    calculate :can_accept_transactions, :boolean do
      expr(not is_header_account and status == :active)
    end
  end
  
  actions do
    read :active_accounts do
      filter expr(status == :active and not is_header_account)
    end
    
    read :by_type do
      argument :account_type, :atom, allow_nil?: false
      filter expr(account_type == ^arg(:account_type))
    end
    
    read :children_of do
      argument :parent_id, Ash.Type.UUID, allow_nil?: false
      filter expr(parent_account_id == ^arg(:parent_id))
      sort [:account_code]
    end
  end
end
```

### Trial Balance Projection

```elixir
defmodule Accountex.GL.Projections.TrialBalance do
  @moduledoc """
  Real-time account balances with debit/credit columns
  
  ## Purpose
  - Period-end reporting
  - Balance verification
  - Multi-period comparison
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "gl_trial_balance"
    repo Accountex.Repo
    
    custom_indexes do
      index [:period_id, :account_id], unique: true
      index [:account_type, :period_id]
    end
  end
  
  attributes do
    uuid_primary_key :id
    attribute :period_id, Ash.Type.UUID, allow_nil?: false
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :account_code, :string
    attribute :account_name, :string
    attribute :account_type, :atom
    
    attribute :beginning_debit_balance, :decimal, default: Decimal.new(0)
    attribute :beginning_credit_balance, :decimal, default: Decimal.new(0)
    attribute :period_debit_amount, :decimal, default: Decimal.new(0)
    attribute :period_credit_amount, :decimal, default: Decimal.new(0)
    attribute :ending_debit_balance, :decimal, default: Decimal.new(0)
    attribute :ending_credit_balance, :decimal, default: Decimal.new(0)
    
    attribute :transaction_count, :integer, default: 0
    attribute :last_updated, :utc_datetime
  end
  
  calculations do
    calculate :net_change, :decimal do
      expr(period_debit_amount - period_credit_amount)
    end
    
    calculate :ending_balance, :decimal do
      expr(ending_debit_balance - ending_credit_balance)
    end
  end
  
  actions do
    read :by_period do
      argument :period_id, Ash.Type.UUID, allow_nil?: false
      filter expr(period_id == ^arg(:period_id))
      sort [:account_code]
    end
    
    read :comparative do
      argument :periods, {:array, Ash.Type.UUID}, allow_nil?: false
      filter expr(period_id in ^arg(:periods))
    end
  end
end
```

### Transaction History Projection

```elixir
defmodule Accountex.GL.Projections.TransactionHistory do
  @moduledoc """
  Detailed journal entries optimized for audit and inquiry
  
  ## Purpose
  - Audit trail maintenance
  - Account inquiry
  - Transaction search
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "gl_transaction_history"
    repo Accountex.Repo
    
    custom_indexes do
      index [:account_id, :posting_date]
      index [:journal_entry_id]
      index [:reference_number]
      index [:source_module, :source_document_id]
    end
  end
  
  attributes do
    uuid_primary_key :id
    attribute :journal_entry_id, Ash.Type.UUID, allow_nil?: false
    attribute :line_number, :integer
    attribute :account_id, Ash.Type.UUID, allow_nil?: false
    attribute :account_code, :string
    attribute :posting_date, :date
    attribute :debit_amount, :decimal
    attribute :credit_amount, :decimal
    attribute :description, :string
    attribute :reference_number, :string
    attribute :journal_type, :atom
    attribute :source_module, :atom
    attribute :source_document_id, Ash.Type.UUID
    attribute :cost_center, :string
    attribute :project_code, :string
    attribute :created_at, :utc_datetime
    attribute :posted_by, Ash.Type.UUID
  end
  
  actions do
    read :by_account do
      argument :account_id, Ash.Type.UUID, allow_nil?: false
      argument :date_from, :date
      argument :date_to, :date
      
      filter expr(account_id == ^arg(:account_id))
      filter expr(posting_date >= ^arg(:date_from)) 
      filter expr(posting_date <= ^arg(:date_to))
      
      sort [posting_date: :desc, journal_entry_id: :desc]
    end
    
    read :search do
      argument :search_term, :string, allow_nil?: false
      
      filter expr(
        fragment("? @@ websearch_to_tsquery(?)", 
          fragment("to_tsvector('english', ? || ' ' || ?)", description, reference_number),
          ^arg(:search_term)
        )
      )
    end
  end
end
```

## Business Rules and Validations

### Account Validation Rules

```elixir
defmodule Accountex.GL.Validators.AccountValidators do
  @moduledoc """
  Business rule validators for GL accounts
  """
  
  use Ash.Resource.Validation
  
  def validate_account_hierarchy(changeset, opts, _context) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_account_id)
    account_type = Ash.Changeset.get_attribute(changeset, :account_type)
    
    if parent_id do
      case get_parent_account(parent_id) do
        {:ok, parent} ->
          if compatible_types?(parent.account_type, account_type) do
            :ok
          else
            {:error, field: :account_type, 
             message: "Account type #{account_type} incompatible with parent type #{parent.account_type}"}
          end
        {:error, _} ->
          {:error, field: :parent_account_id, message: "Parent account not found"}
      end
    else
      :ok
    end
  end
  
  def validate_no_circular_reference(changeset, opts, _context) do
    account_id = changeset.data.id
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_account_id)
    
    if parent_id && creates_circular_reference?(account_id, parent_id) do
      {:error, field: :parent_account_id, message: "Circular reference detected"}
    else
      :ok
    end
  end
  
  def validate_system_account_immutability(changeset, opts, _context) do
    if changeset.data.is_system_account do
      {:error, message: "System accounts cannot be modified"}
    else
      :ok
    end
  end
  
  defp compatible_types?(:asset, type) when type in [:asset], do: true
  defp compatible_types?(:liability, type) when type in [:liability], do: true
  defp compatible_types?(:equity, type) when type in [:equity], do: true
  defp compatible_types?(:revenue, type) when type in [:revenue], do: true
  defp compatible_types?(:expense, type) when type in [:expense], do: true
  defp compatible_types?(_, _), do: false
end
```

### Journal Entry Validation Rules

```elixir
defmodule Accountex.GL.Validators.JournalEntryValidators do
  @moduledoc """
  Business rule validators for journal entries
  """
  
  use Ash.Resource.Validation
  
  def validate_balanced_entry(changeset, _opts, _context) do
    lines = Ash.Changeset.get_attribute(changeset, :lines) || []
    
    total_debits = Enum.reduce(lines, Decimal.new(0), fn line, acc ->
      Decimal.add(acc, line.debit_amount || Decimal.new(0))
    end)
    
    total_credits = Enum.reduce(lines, Decimal.new(0), fn line, acc ->
      Decimal.add(acc, line.credit_amount || Decimal.new(0))
    end)
    
    if Decimal.compare(total_debits, total_credits) == :eq do
      :ok
    else
      {:error, field: :lines, 
       message: "Entry not balanced. Debits: #{total_debits}, Credits: #{total_credits}"}
    end
  end
  
  def validate_posting_period(changeset, _opts, _context) do
    posting_date = Ash.Changeset.get_attribute(changeset, :posting_date)
    
    case get_period_for_date(posting_date) do
      {:ok, period} when period.status == :open -> :ok
      {:ok, period} -> 
        {:error, field: :posting_date, 
         message: "Period #{period.period_number} is #{period.status}"}
      {:error, _} ->
        {:error, field: :posting_date, 
         message: "No period defined for #{posting_date}"}
    end
  end
  
  def validate_accounts_active(changeset, _opts, _context) do
    lines = Ash.Changeset.get_attribute(changeset, :lines) || []
    
    inactive_accounts = Enum.filter(lines, fn line ->
      case get_account(line.account_id) do
        {:ok, account} -> account.status != :active
        _ -> true
      end
    end)
    
    if Enum.empty?(inactive_accounts) do
      :ok
    else
      {:error, field: :lines, 
       message: "Some accounts are inactive or not found"}
    end
  end
  
  def validate_minimum_lines(changeset, _opts, _context) do
    lines = Ash.Changeset.get_attribute(changeset, :lines) || []
    
    if length(lines) >= 2 do
      :ok
    else
      {:error, field: :lines, 
       message: "Journal entry must have at least 2 lines"}
    end
  end
end
```

### Period Management Rules

```elixir
defmodule Accountex.GL.Validators.PeriodValidators do
  @moduledoc """
  Business rule validators for fiscal periods
  """
  
  use Ash.Resource.Validation
  
  def validate_sequential_period(changeset, _opts, _context) do
    period_number = Ash.Changeset.get_attribute(changeset, :period_number)
    fiscal_year = Ash.Changeset.get_attribute(changeset, :fiscal_year)
    
    case get_last_period(fiscal_year) do
      {:ok, last_period} ->
        expected_number = last_period.period_number + 1
        if period_number == expected_number do
          :ok
        else
          {:error, field: :period_number,
           message: "Expected period #{expected_number}, got #{period_number}"}
        end
      {:error, :not_found} ->
        if period_number == 1 do
          :ok
        else
          {:error, field: :period_number,
           message: "First period must be numbered 1"}
        end
    end
  end
  
  def validate_no_date_overlap(changeset, _opts, _context) do
    start_date = Ash.Changeset.get_attribute(changeset, :start_date)
    end_date = Ash.Changeset.get_attribute(changeset, :end_date)
    fiscal_year = Ash.Changeset.get_attribute(changeset, :fiscal_year)
    
    overlapping_periods = find_overlapping_periods(fiscal_year, start_date, end_date)
    
    if Enum.empty?(overlapping_periods) do
      :ok
    else
      {:error, field: :start_date,
       message: "Date range overlaps with existing periods"}
    end
  end
  
  def validate_closing_prerequisites(changeset, _opts, _context) do
    period_id = Ash.Changeset.get_attribute(changeset, :period_id)
    
    checklist = [
      check_trial_balance_balanced(period_id),
      check_subledgers_reconciled(period_id),
      check_no_unposted_entries(period_id),
      check_mandatory_adjustments(period_id)
    ]
    
    case Enum.find(checklist, fn result -> result != :ok end) do
      nil -> :ok
      {:error, reason} -> {:error, message: reason}
    end
  end
end
```

## Integration with Other Modules

### Sales Order Integration

```elixir
defmodule Accountex.GL.Integrations.SalesOrderBridge do
  @moduledoc """
  Handles journal entry creation from Sales Order events
  """
  
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "GLSalesOrderIntegration"
    
  alias Accountex.SalesOrders.Events.{InvoicePosted, CreditMemoIssued}
  
  def handle(%InvoicePosted{} = event, _metadata) do
    journal_lines = build_revenue_recognition_entries(event)
    
    command = %Accountex.GL.Commands.CreateJournalEntry{
      journal_date: Date.utc_today(),
      posting_date: event.invoice_date,
      description: "Sales Invoice #{event.invoice_number}",
      journal_type: :automatic,
      source_module: :sales_orders,
      source_document_id: event.invoice_id,
      lines: journal_lines,
      status: :draft,
      created_by: event.posted_by
    }
    
    case validate_account_mapping(journal_lines) do
      :ok -> 
        Accountex.GL.dispatch_command(command)
        if event.auto_post, do: post_journal_entry(command.id)
      {:error, missing_accounts} ->
        notify_configuration_error(missing_accounts)
    end
    
    :ok
  end
  
  defp build_revenue_recognition_entries(invoice) do
    ar_account = get_ar_account(invoice.customer_id)
    revenue_account = get_revenue_account(invoice.product_category)
    tax_account = get_tax_payable_account(invoice.tax_code)
    
    [
      %{
        account_id: ar_account.id,
        debit_amount: invoice.total_amount,
        credit_amount: nil,
        description: "AR - Customer #{invoice.customer_name}"
      },
      %{
        account_id: revenue_account.id,
        debit_amount: nil,
        credit_amount: invoice.net_amount,
        description: "Revenue recognition"
      },
      %{
        account_id: tax_account.id,
        debit_amount: nil,
        credit_amount: invoice.tax_amount,
        description: "Sales tax payable"
      }
    ]
  end
end
```

### Inventory Integration

```elixir
defmodule Accountex.GL.Integrations.InventoryBridge do
  @moduledoc """
  Handles cost of goods sold and inventory valuation entries
  """
  
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "GLInventoryIntegration"
    
  alias Accountex.Inventory.Events.{GoodsShipped, InventoryAdjusted, CycleCountCompleted}
  
  def handle(%GoodsShipped{} = event, _metadata) do
    # Create COGS and inventory reduction entries
    entries = build_cogs_entries(event)
    
    command = %Accountex.GL.Commands.CreateJournalEntry{
      journal_date: Date.utc_today(),
      posting_date: event.ship_date,
      description: "COGS for Shipment #{event.shipment_number}",
      journal_type: :automatic,
      source_module: :inventory,
      source_document_id: event.shipment_id,
      lines: entries,
      status: :draft
    }
    
    Accountex.GL.dispatch_command(command)
    :ok
  end
  
  def handle(%InventoryAdjusted{} = event, _metadata) do
    # Handle inventory adjustments
    entries = case event.adjustment_type do
      :physical_count -> build_physical_adjustment_entries(event)
      :write_off -> build_write_off_entries(event)
      :revaluation -> build_revaluation_entries(event)
    end
    
    create_adjustment_journal(entries, event)
    :ok
  end
  
  defp build_cogs_entries(shipment) do
    inventory_account = get_inventory_account(shipment.warehouse_id)
    cogs_account = get_cogs_account(shipment.product_category)
    
    Enum.flat_map(shipment.items, fn item ->
      [
        %{
          account_id: cogs_account.id,
          debit_amount: item.cost_amount,
          credit_amount: nil,
          description: "COGS - #{item.product_code}",
          cost_center: shipment.cost_center
        },
        %{
          account_id: inventory_account.id,
          debit_amount: nil,
          credit_amount: item.cost_amount,
          description: "Inventory reduction - #{item.product_code}",
          cost_center: shipment.cost_center
        }
      ]
    end)
  end
end
```

### Payroll Integration

```elixir
defmodule Accountex.GL.Integrations.PayrollBridge do
  @moduledoc """
  Processes payroll journal entries with complex distributions
  """
  
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "GLPayrollIntegration"
    
  def handle(%PayrollProcessed{} = event, _metadata) do
    # Build complex payroll distribution entries
    wage_entries = build_wage_entries(event)
    tax_entries = build_tax_entries(event)
    benefit_entries = build_benefit_entries(event)
    accrual_entries = build_accrual_entries(event)
    
    all_entries = wage_entries ++ tax_entries ++ benefit_entries ++ accrual_entries
    
    # Validate department and cost center distributions
    validate_distributions(all_entries)
    
    command = %Accountex.GL.Commands.CreateJournalEntry{
      journal_date: event.pay_date,
      posting_date: event.pay_date,
      description: "Payroll for period #{event.pay_period}",
      journal_type: :automatic,
      source_module: :payroll,
      source_document_id: event.payroll_batch_id,
      lines: all_entries,
      status: :draft
    }
    
    Accountex.GL.dispatch_command(command)
    :ok
  end
  
  defp build_wage_entries(payroll) do
    Enum.flat_map(payroll.employees, fn emp ->
      [
        %{
          account_id: get_wage_expense_account(emp.department).id,
          debit_amount: emp.gross_pay,
          credit_amount: nil,
          description: "Wages expense",
          cost_center: emp.cost_center,
          project_code: emp.project_code
        },
        %{
          account_id: get_payroll_payable_account().id,
          debit_amount: nil,
          credit_amount: emp.net_pay,
          description: "Net pay payable"
        }
      ]
    end)
  end
end
```

## Agentic Capabilities and Automation

### Intelligent Journal Validation Agent

```elixir
defmodule Accountex.GL.Agents.JournalValidator do
  @moduledoc """
  Jido agent for intelligent journal entry validation and anomaly detection
  """
  
  use Jido.Agent,
    name: "gl_journal_validator",
    description: "Validates journal entries for errors and anomalies"
    
  def validate_journal_entry(%{entry: entry, context: context}) do
    validations = [
      validate_unusual_amounts(entry, context),
      validate_account_combinations(entry, context),
      validate_posting_patterns(entry, context),
      check_fraud_indicators(entry, context)
    ]
    
    case run_validations(validations) do
      {:ok, _} -> 
        {:ok, %{status: :approved, confidence: calculate_confidence(validations)}}
      {:warning, issues} ->
        {:review_required, %{issues: issues, suggested_corrections: suggest_corrections(issues)}}
      {:error, violations} ->
        {:rejected, %{violations: violations, remediation: provide_remediation(violations)}}
    end
  end
  
  defp validate_unusual_amounts(entry, context) do
    historical_stats = get_historical_statistics(context.account_ids)
    
    anomalies = Enum.filter(entry.lines, fn line ->
      amount = line.debit_amount || line.credit_amount
      stats = historical_stats[line.account_id]
      
      deviation = calculate_standard_deviation(amount, stats)
      deviation > 3.0  # More than 3 standard deviations
    end)
    
    if Enum.empty?(anomalies) do
      {:ok, :amounts_normal}
    else
      {:warning, {:unusual_amounts, anomalies}}
    end
  end
  
  defp validate_account_combinations(entry, context) do
    ml_model = load_combination_model()
    
    combinations = extract_account_pairs(entry.lines)
    predictions = ml_model.predict(combinations)
    
    suspicious = Enum.filter(predictions, fn pred -> pred.confidence < 0.3 end)
    
    if Enum.empty?(suspicious) do
      {:ok, :combinations_valid}
    else
      {:warning, {:unusual_combinations, suspicious}}
    end
  end
end
```

### Automated Reconciliation Agent

```elixir
defmodule Accountex.GL.Agents.ReconciliationAgent do
  @moduledoc """
  Jido agent for continuous reconciliation monitoring
  """
  
  use Jido.Agent,
    name: "gl_reconciliation_agent",
    description: "Monitors account balances and identifies discrepancies"
    
  def monitor_reconciliation(%{accounts: accounts, threshold: threshold}) do
    discrepancies = Enum.flat_map(accounts, fn account ->
      case check_account_reconciliation(account) do
        {:ok, _} -> []
        {:discrepancy, details} -> [details]
      end
    end)
    
    if Enum.empty?(discrepancies) do
      {:ok, :all_reconciled}
    else
      prioritized = prioritize_discrepancies(discrepancies, threshold)
      {:action_required, %{
        critical: filter_critical(prioritized),
        warnings: filter_warnings(prioritized),
        suggested_actions: generate_resolution_steps(prioritized)
      }}
    end
  end
  
  defp check_account_reconciliation(account) do
    gl_balance = get_gl_balance(account.id)
    
    case account.reconciliation_type do
      :bank ->
        bank_balance = get_bank_balance(account.bank_account_id)
        compare_balances(gl_balance, bank_balance, account.expected_variance)
      
      :subledger ->
        subledger_balance = get_subledger_balance(account.subledger_account)
        compare_with_tolerance(gl_balance, subledger_balance)
      
      :intercompany ->
        counterparty_balance = get_counterparty_balance(account.counterparty)
        validate_intercompany_balance(gl_balance, counterparty_balance)
    end
  end
  
  def auto_clear_reconciling_items(%{account: account, items: items}) do
    matched_items = match_reconciling_items(items)
    
    Enum.each(matched_items, fn match ->
      clear_items(match.gl_item, match.external_item)
    end)
    
    unmatched = items -- Enum.flat_map(matched_items, & &1.items)
    
    {:ok, %{
      cleared: length(matched_items),
      remaining: length(unmatched),
      suggested_matches: suggest_matches(unmatched)
    }}
  end
end
```

### Period Close Orchestration Agent

```elixir
defmodule Accountex.GL.Agents.PeriodCloseOrchestrator do
  @moduledoc """
  Jido agent for managing period-end closing procedures
  """
  
  use Jido.Agent,
    name: "gl_period_close_agent",
    description: "Orchestrates month-end and year-end closing processes"
    
  def orchestrate_period_close(%{period: period, options: options}) do
    workflow = build_closing_workflow(period, options)
    
    execute_workflow(workflow)
  end
  
  defp build_closing_workflow(period, options) do
    base_tasks = [
      {:validate_open_transactions, &validate_no_pending_transactions/1},
      {:reconcile_subledgers, &reconcile_all_subledgers/1},
      {:run_allocations, &execute_period_allocations/1},
      {:generate_accruals, &create_accrual_entries/1},
      {:validate_trial_balance, &ensure_balanced_trial_balance/1}
    ]
    
    additional_tasks = if period.period_type == :year_end do
      [
        {:close_income_accounts, &close_revenue_expense_accounts/1},
        {:calculate_retained_earnings, &update_retained_earnings/1},
        {:generate_financial_statements, &create_annual_statements/1}
      ]
    else
      []
    end
    
    base_tasks ++ additional_tasks
  end
  
  def monitor_closing_progress(%{period_id: period_id}) do
    status = get_closing_status(period_id)
    
    %{
      overall_progress: calculate_progress_percentage(status),
      completed_tasks: status.completed_tasks,
      pending_tasks: status.pending_tasks,
      blocked_tasks: identify_blockers(status),
      estimated_completion: estimate_completion_time(status)
    }
  end
  
  defp execute_workflow(workflow) do
    Enum.reduce_while(workflow, {:ok, []}, fn {task_name, task_fn}, {:ok, results} ->
      case task_fn.(task_name) do
        {:ok, result} ->
          {:cont, {:ok, [{task_name, result} | results]}}
        {:error, reason} ->
          {:halt, {:error, {task_name, reason}}}
        {:skip, reason} ->
          {:cont, {:ok, [{task_name, {:skipped, reason}} | results]}}
      end
    end)
  end
end
```

### Financial Analysis Agent

```elixir
defmodule Accountex.GL.Agents.FinancialAnalyst do
  @moduledoc """
  Jido agent for financial analysis and insights
  """
  
  use Jido.Agent,
    name: "gl_financial_analyst",
    description: "Provides financial analysis and recommendations"
    
  def analyze_financial_position(%{period: period, options: options}) do
    metrics = calculate_financial_metrics(period)
    trends = analyze_trends(period, options.lookback_periods)
    anomalies = detect_anomalies(metrics, trends)
    
    insights = generate_insights(metrics, trends, anomalies)
    
    %{
      key_metrics: format_metrics(metrics),
      trend_analysis: format_trends(trends),
      anomalies: anomalies,
      insights: insights,
      recommendations: generate_recommendations(insights)
    }
  end
  
  defp calculate_financial_metrics(period) do
    trial_balance = get_trial_balance(period)
    
    %{
      current_ratio: calculate_current_ratio(trial_balance),
      quick_ratio: calculate_quick_ratio(trial_balance),
      debt_to_equity: calculate_debt_to_equity(trial_balance),
      gross_margin: calculate_gross_margin(trial_balance),
      operating_margin: calculate_operating_margin(trial_balance),
      return_on_assets: calculate_roa(trial_balance),
      return_on_equity: calculate_roe(trial_balance)
    }
  end
  
  def forecast_cash_flow(%{period: period, horizon: horizon}) do
    historical_data = get_historical_cash_flows()
    current_position = get_current_cash_position()
    
    forecast_model = train_forecast_model(historical_data)
    projections = generate_projections(forecast_model, horizon)
    
    %{
      current_position: current_position,
      projected_flows: projections,
      confidence_intervals: calculate_confidence_intervals(projections),
      risk_factors: identify_cash_flow_risks(projections),
      recommendations: suggest_cash_management_actions(projections)
    }
  end
end
```

## Error Handling and Recovery

### Transaction Rollback Procedures

```elixir
defmodule Accountex.GL.Recovery.TransactionRollback do
  @moduledoc """
  Handles failed transaction rollback and recovery
  """
  
  def handle_posting_failure(journal_entry_id, error) do
    case error do
      {:validation_error, details} ->
        rollback_partial_posting(journal_entry_id)
        create_error_log(journal_entry_id, details)
        notify_user(journal_entry_id, :validation_failed, details)
        
      {:system_error, details} ->
        preserve_draft_state(journal_entry_id)
        schedule_retry(journal_entry_id, calculate_backoff())
        escalate_if_critical(journal_entry_id, details)
        
      {:integration_error, module, details} ->
        queue_for_manual_review(journal_entry_id, module, details)
        create_compensation_entry_if_needed(journal_entry_id)
    end
  end
  
  defp rollback_partial_posting(journal_entry_id) do
    # Identify any partially updated balances
    affected_accounts = get_affected_accounts(journal_entry_id)
    
    # Reverse any balance updates
    Enum.each(affected_accounts, fn account ->
      restore_previous_balance(account)
    end)
    
    # Mark entry as failed
    update_entry_status(journal_entry_id, :failed)
  end
  
  def recover_from_period_close_failure(period_id, failure_point) do
    recovery_strategy = determine_recovery_strategy(failure_point)
    
    case recovery_strategy do
      :rollback_complete ->
        rollback_entire_close(period_id)
        
      :rollback_partial ->
        rollback_to_checkpoint(period_id, failure_point)
        
      :retry_from_point ->
        retry_from_failure_point(period_id, failure_point)
        
      :manual_intervention ->
        create_manual_recovery_task(period_id, failure_point)
    end
  end
end
```

### Integration Failure Management

```elixir
defmodule Accountex.GL.Recovery.IntegrationFailures do
  @moduledoc """
  Manages failures in module integrations
  """
  
  use GenServer
  
  def handle_integration_timeout(source_module, transaction) do
    # Queue transaction for later processing
    queue_transaction(source_module, transaction)
    
    # Set up monitoring for module availability
    monitor_module_health(source_module)
    
    # Create placeholder entry if critical
    if critical_transaction?(transaction) do
      create_pending_entry(transaction)
    end
    
    # Notify relevant parties
    notify_integration_failure(source_module, transaction)
  end
  
  def retry_failed_integrations(source_module) do
    pending_transactions = get_queued_transactions(source_module)
    
    results = Enum.map(pending_transactions, fn transaction ->
      case retry_integration(source_module, transaction) do
        {:ok, result} ->
          remove_from_queue(transaction.id)
          {:success, transaction.id, result}
          
        {:error, reason} ->
          increment_retry_count(transaction.id)
          handle_retry_failure(transaction, reason)
      end
    end)
    
    summarize_retry_results(results)
  end
  
  defp handle_retry_failure(transaction, reason) do
    if transaction.retry_count >= max_retries() do
      move_to_dead_letter_queue(transaction)
      create_manual_intervention_task(transaction)
    else
      reschedule_retry(transaction)
    end
  end
end
```

### Data Consistency Recovery

```elixir
defmodule Accountex.GL.Recovery.ConsistencyChecker do
  @moduledoc """
  Ensures data consistency and recovery from inconsistencies
  """
  
  def check_and_repair_consistency(options \\ %{}) do
    checks = [
      check_trial_balance_equality(),
      check_account_hierarchy_integrity(),
      check_period_continuity(),
      check_journal_entry_balance(),
      check_projection_consistency()
    ]
    
    issues = Enum.flat_map(checks, fn check ->
      case check do
        {:ok, _} -> []
        {:error, issue} -> [issue]
      end
    end)
    
    if Enum.empty?(issues) do
      {:ok, :consistent}
    else
      repair_results = attempt_auto_repair(issues)
      report_consistency_status(repair_results)
    end
  end
  
  defp check_trial_balance_equality() do
    trial_balance = calculate_current_trial_balance()
    
    total_debits = sum_debits(trial_balance)
    total_credits = sum_credits(trial_balance)
    
    if Decimal.compare(total_debits, total_credits) == :eq do
      {:ok, :balanced}
    else
      {:error, %{
        type: :trial_balance_imbalance,
        debits: total_debits,
        credits: total_credits,
        difference: Decimal.sub(total_debits, total_credits)
      }}
    end
  end
  
  def rebuild_projections_from_events(start_date \\ nil) do
    # Event sourcing recovery - replay events
    events = if start_date do
      get_events_from_date(start_date)
    else
      get_all_events()
    end
    
    # Clear existing projections
    clear_projections()
    
    # Replay events in order
    Enum.each(events, fn event ->
      apply_event_to_projections(event)
    end)
    
    # Verify consistency after rebuild
    verify_rebuilt_projections()
  end
end
```

## Security and Audit Considerations

### Transaction Authorization Matrix

```elixir
defmodule Accountex.GL.Security.AuthorizationMatrix do
  @moduledoc """
  Role-based security controls for GL operations
  """
  
  def authorize_action(user, action, resource) do
    user_roles = get_user_roles(user)
    required_permissions = get_required_permissions(action, resource)
    
    if has_all_permissions?(user_roles, required_permissions) do
      check_additional_constraints(user, action, resource)
    else
      {:error, :insufficient_permissions}
    end
  end
  
  defp check_additional_constraints(user, :post_journal_entry, entry) do
    cond do
      entry.total_amount > user.posting_limit ->
        {:error, :exceeds_posting_limit}
      
      entry.journal_type == :manual && !user.can_post_manual ->
        {:error, :cannot_post_manual_entries}
      
      affects_closed_period?(entry) && !user.can_post_to_closed ->
        {:error, :cannot_post_to_closed_period}
      
      true ->
        {:ok, :authorized}
    end
  end
  
  def enforce_segregation_of_duties(transaction) do
    creator = transaction.created_by
    approver = transaction.approved_by
    poster = transaction.posted_by
    
    violations = []
    
    if creator == approver do
      violations = [:creator_cannot_approve | violations]
    end
    
    if creator == poster && transaction.amount > self_posting_limit() do
      violations = [:creator_cannot_post_high_value | violations]
    end
    
    if approver == poster && transaction.journal_type == :adjustment do
      violations = [:approver_cannot_post_adjustments | violations]
    end
    
    if Enum.empty?(violations) do
      {:ok, :no_violations}
    else
      {:error, {:segregation_violations, violations}}
    end
  end
end
```

### Audit Trail Requirements

```elixir
defmodule Accountex.GL.Audit.AuditLogger do
  @moduledoc """
  Comprehensive audit logging for GL transactions
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "gl_audit_log"
    repo Accountex.Repo
  end
  
  attributes do
    uuid_primary_key :id
    attribute :entity_type, :atom, allow_nil?: false
    attribute :entity_id, Ash.Type.UUID, allow_nil?: false
    attribute :action, :atom, allow_nil?: false
    attribute :user_id, Ash.Type.UUID, allow_nil?: false
    attribute :user_roles, {:array, :string}
    attribute :timestamp, :utc_datetime, allow_nil?: false
    attribute :ip_address, :string
    attribute :session_id, :string
    
    attribute :changes, :map  # Before/after values
    attribute :metadata, :map  # Additional context
    attribute :digital_signature, :string  # For non-repudiation
  end
  
  def log_transaction(action, entity, user, context) do
    audit_entry = %{
      entity_type: entity.__struct__,
      entity_id: entity.id,
      action: action,
      user_id: user.id,
      user_roles: user.roles,
      timestamp: DateTime.utc_now(),
      ip_address: context.ip_address,
      session_id: context.session_id,
      changes: capture_changes(action, entity),
      metadata: build_metadata(context),
      digital_signature: generate_signature(entity, user)
    }
    
    # Ensure immutability
    create_immutable_record(audit_entry)
    
    # Archive for compliance
    if requires_long_term_archive?(action) do
      archive_to_cold_storage(audit_entry)
    end
  end
  
  defp generate_signature(entity, user) do
    data_to_sign = "#{entity.id}|#{user.id}|#{DateTime.utc_now()}"
    sign_with_private_key(data_to_sign)
  end
end
```

## Performance and Scalability Patterns

### Event Stream Optimization

```elixir
defmodule Accountex.GL.Performance.EventStreamOptimizer do
  @moduledoc """
  Optimizes event stream processing for high volume
  """
  
  def configure_partitioning(config) do
    %{
      partition_strategy: :by_company,
      partition_count: calculate_optimal_partitions(),
      snapshot_frequency: 1000,  # Events per snapshot
      archive_after_days: 90,
      compression: :enabled
    }
  end
  
  def optimize_event_replay(aggregate_id, target_version) do
    # Use snapshots to reduce replay time
    latest_snapshot = get_latest_snapshot(aggregate_id)
    
    if latest_snapshot && latest_snapshot.version < target_version do
      # Start from snapshot
      events = get_events_after(aggregate_id, latest_snapshot.version, target_version)
      apply_from_snapshot(latest_snapshot, events)
    else
      # Full replay
      events = get_events(aggregate_id, target_version)
      apply_from_beginning(events)
    end
  end
  
  def batch_process_events(events) do
    # Group events for efficient processing
    grouped = Enum.group_by(events, & &1.aggregate_id)
    
    # Process in parallel with flow control
    Task.async_stream(
      grouped,
      fn {aggregate_id, aggregate_events} ->
        process_aggregate_events(aggregate_id, aggregate_events)
      end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: 30_000
    )
    |> Enum.to_list()
  end
end
```

### Caching Strategies

```elixir
defmodule Accountex.GL.Performance.CacheManager do
  @moduledoc """
  Manages caching for frequently accessed GL data
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Initialize caches
    :ets.new(:gl_account_cache, [:set, :named_table, :public])
    :ets.new(:gl_balance_cache, [:set, :named_table, :public])
    :ets.new(:gl_period_cache, [:set, :named_table, :public])
    
    # Schedule cache refresh
    schedule_refresh()
    
    {:ok, %{}}
  end
  
  def get_account(account_id) do
    case :ets.lookup(:gl_account_cache, account_id) do
      [{^account_id, account}] -> {:ok, account}
      [] -> 
        case load_and_cache_account(account_id) do
          {:ok, account} -> {:ok, account}
          error -> error
        end
    end
  end
  
  def get_account_balance(account_id, period_id) do
    cache_key = {account_id, period_id}
    
    case :ets.lookup(:gl_balance_cache, cache_key) do
      [{^cache_key, balance, timestamp}] ->
        if fresh?(timestamp) do
          {:ok, balance}
        else
          refresh_balance(account_id, period_id)
        end
      [] ->
        calculate_and_cache_balance(account_id, period_id)
    end
  end
  
  defp fresh?(timestamp) do
    DateTime.diff(DateTime.utc_now(), timestamp, :second) < 300  # 5 minutes
  end
  
  def invalidate_account(account_id) do
    :ets.delete(:gl_account_cache, account_id)
    
    # Also invalidate related balances
    :ets.match_delete(:gl_balance_cache, {{account_id, :_}, :_, :_})
  end
end
```

### Database Optimization

```elixir
defmodule Accountex.GL.Performance.DatabaseOptimizer do
  @moduledoc """
  Database optimization strategies for GL operations
  """
  
  def optimize_trial_balance_query(period_id) do
    # Use materialized view for complex calculations
    """
    SELECT 
      a.account_code,
      a.account_name,
      a.account_type,
      COALESCE(tb.beginning_debit, 0) as beginning_debit,
      COALESCE(tb.beginning_credit, 0) as beginning_credit,
      COALESCE(tb.period_debit, 0) as period_debit,
      COALESCE(tb.period_credit, 0) as period_credit,
      COALESCE(tb.ending_debit, 0) as ending_debit,
      COALESCE(tb.ending_credit, 0) as ending_credit
    FROM gl_accounts a
    LEFT JOIN gl_trial_balance_mv tb ON a.id = tb.account_id
    WHERE tb.period_id = $1
    ORDER BY a.account_code
    """
  end
  
  def create_performance_indexes() do
    indexes = [
      "CREATE INDEX idx_journal_entries_posting_date ON gl_journal_entries(posting_date)",
      "CREATE INDEX idx_journal_lines_account_date ON gl_journal_lines(account_id, posting_date)",
      "CREATE INDEX idx_account_balances_period ON gl_account_balances(period_id, account_id)",
      "CREATE INDEX idx_audit_log_entity ON gl_audit_log(entity_type, entity_id, timestamp)"
    ]
    
    Enum.each(indexes, &execute_ddl/1)
  end
  
  def partition_large_tables() do
    # Partition transaction history by date
    """
    CREATE TABLE gl_transaction_history_#{year}_#{month} 
    PARTITION OF gl_transaction_history
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
    """
  end
end
```

## Conclusion

The General Ledger module provides a robust, scalable foundation for financial accounting within the Accountex system. Through event sourcing with Commanded and domain-driven design with Ash, the module maintains strict accounting principles while enabling real-time financial insights. The integration of Jido agents automates routine tasks and provides intelligent monitoring that enhances accuracy and compliance.

The modular architecture ensures the GL can operate independently or as part of a comprehensive ERP system, with graceful handling of module availability. Event-driven integration patterns enable loose coupling with other modules while maintaining data consistency. This design enables organizations to start with core GL functionality and progressively adopt additional modules as needs evolve, all while maintaining complete audit trails and regulatory compliance throughout the system lifecycle.
