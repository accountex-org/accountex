# Building a Modular Accounting System in Elixir with Ash Framework

A well-designed accounting system needs both flexibility and rigor. Elixir's functional paradigm combined with Ash Framework's declarative resources creates an ideal foundation for financial applications that are both modular and reliable.

## Architectural overview

Creating a modular accounting system in Elixir leverages the language's inherent strengths in concurrency, fault tolerance, and functional programming. The Ash Framework provides a declarative way to define resources and business rules, while AshCommanded enables robust CQRS and Event Sourcing patterns.

The proposed architecture uses an umbrella application structure with separate applications for each accounting module (Inventory Control, Sales Orders, Account Receivables, etc.), coordinated by a central System Manager that can dynamically load modules on demand.

## Modular application structure

### Umbrella project organization

The recommended structure organizes accounting modules as separate applications within an umbrella project:

```
accounting_system/
├── apps/
│   ├── inventory/
│   ├── sales_orders/
│   ├── accounts_receivable/
│   ├── purchasing/
│   ├── accounts_payable/
│   ├── general_ledger/
│   └── system_manager/
├── config/
├── mix.exs
└── README.md
```

Each module should maintain clear boundaries with well-defined public APIs. The General Ledger module typically forms the core of the system, with other modules interacting with it through defined interfaces.

### Individual application structure

Each accounting module should follow a consistent structure:

```
apps/module_name/
├── lib/
│   ├── module_name/
│   │   ├── application.ex    # Application callback module
│   │   ├── supervisor.ex     # Supervisor tree
│   │   ├── resources/        # Ash resources
│   │   ├── domains/          # Ash domains
│   │   └── api/              # Public API
│   └── module_name.ex        # Main entry point
├── config/
├── mix.exs
└── test/
```

In the `mix.exs` file of each application, explicitly define dependencies on other umbrella applications:

```elixir
def deps do
  [
    {:general_ledger, in_umbrella: true},
    {:ash, "~> 2.9"},
    {:ash_commanded, "~> 0.1.0"}
    # Other dependencies
  ]
end
```

## System Manager implementation

The System Manager serves as the orchestrator for loading and managing the configured modules at runtime. Implementation as a GenServer provides the necessary state management:

```elixir
defmodule AccountingSystem.SystemManager do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def load_module(module_name) when is_atom(module_name) do
    GenServer.call(__MODULE__, {:load_module, module_name})
  end

  def unload_module(module_name) when is_atom(module_name) do
    GenServer.call(__MODULE__, {:unload_module, module_name})
  end

  def get_loaded_modules do
    GenServer.call(__MODULE__, :get_loaded_modules)
  end

  # Server callbacks
  @impl true
  def init(_opts) do
    modules_to_load = Application.get_env(:system_manager, :autoload_modules, [])
    loaded_modules = Enum.reduce(modules_to_load, %{}, fn module, acc ->
      case ensure_started(module) do
        {:ok, _} -> Map.put(acc, module, :loaded)
        {:error, reason} -> Map.put(acc, module, {:error, reason})
      end
    end)

    {:ok, %{loaded_modules: loaded_modules}}
  end

  @impl true
  def handle_call({:load_module, module_name}, _from, state) do
    case ensure_started(module_name) do
      {:ok, _} ->
        new_state = put_in(state, [:loaded_modules, module_name], :loaded)
        {:reply, {:ok, module_name}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_module, module_name}, _from, state) do
    case Application.stop(module_name) do
      :ok ->
        new_state = put_in(state, [:loaded_modules, module_name], :unloaded)
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_loaded_modules, _from, state) do
    loaded = state.loaded_modules
      |> Enum.filter(fn {_, status} -> status == :loaded end)
      |> Enum.map(fn {module, _} -> module end)
    
    {:reply, loaded, state}
  end

  # Private functions
  defp ensure_started(module_name) do
    Application.load(module_name)
    Application.ensure_all_started(module_name)
  end
end
```

Configure which modules should be automatically loaded in your `config.exs`:

```elixir
config :system_manager, :autoload_modules, [
  :general_ledger,
  :accounts_receivable,
  :accounts_payable
  # Other modules to load on startup
]
```

Add the System Manager to your supervision tree:

```elixir
def start(_type, _args) do
  children = [
    {AccountingSystem.SystemManager, []}
    # Other children
  ]

  opts = [strategy: :one_for_one, name: AccountingSystem.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Runtime module discovery

To allow applications to query which other modules are loaded at runtime, implement a registry interface:

```elixir
defmodule AccountingSystem.Registry do
  @doc """
  Returns a list of all currently loaded accounting modules.
  """
  def available_modules do
    AccountingSystem.SystemManager.get_loaded_modules()
  end

  @doc """
  Checks if a specific module is loaded and available.
  """
  def module_available?(module_name) when is_atom(module_name) do
    module_name in available_modules()
  end

  @doc """
  Returns module metadata with capabilities.
  """
  def module_capabilities(module_name) when is_atom(module_name) do
    if module_available?(module_name) do
      {:ok, module_name.__info__(:functions)}
    else
      {:error, :module_not_available}
    end
  end
end
```

Each module should provide metadata about its capabilities:

```elixir
defmodule AccountingSystem.GeneralLedger do
  @behaviour AccountingSystem.ModuleBehaviour

  @metadata %{
    name: :general_ledger,
    description: "General Ledger accounting functionality",
    version: "1.0.0",
    dependencies: [:system_manager],
    features: [:account_management, :journal_entries, :reporting]
  }

  @impl true
  def metadata, do: @metadata

  # Module implementation
end
```

## ETS-based function overrides

A key requirement is supporting function overrides via ETS tables for business logic customization. Here's a complete implementation:

```elixir
defmodule FunctionRegistry do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def register_function(registry, key, module, function, arity) do
    GenServer.call(registry, {:register, key, {module, function, arity}})
  end

  def lookup_function(registry, key) do
    case :ets.lookup(registry_table_name(registry), key) do
      [{^key, mfa}] -> {:ok, mfa}
      [] -> :error
    end
  end

  def call_function(registry, key, args) do
    case lookup_function(registry, key) do
      {:ok, {module, function, _arity}} ->
        apply(module, function, args)
      :error ->
        {:error, :function_not_found}
    end
  end

  # Server callbacks
  def init(:ok) do
    table = :ets.new(registry_table_name(self()), [
      :set, 
      :protected, 
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
    {:ok, %{table: table}}
  end

  def handle_call({:register, key, mfa}, _from, state) do
    :ets.insert(state.table, {key, mfa})
    {:reply, :ok, state}
  end

  # Helper function to ensure consistent table naming
  defp registry_table_name(registry) when is_pid(registry) do
    :"function_registry_#{:erlang.pid_to_list(registry)}"
  end
  defp registry_table_name(registry_name) when is_atom(registry_name) do
    :"function_registry_#{registry_name}"
  end
end
```

Implementing business logic with customizable functions:

```elixir
defmodule Accounting.BusinessLogic do
  @callback calculate_tax(amount :: Decimal.t()) :: Decimal.t()
  @callback apply_discount(amount :: Decimal.t(), rate :: Decimal.t()) :: Decimal.t()
  
  # Default implementations
  def calculate_tax(amount) do
    impl = get_implementation(:calculate_tax)
    apply_implementation(impl, [amount])
  end
  
  def apply_discount(amount, rate) do
    impl = get_implementation(:apply_discount)
    apply_implementation(impl, [amount, rate])
  end
  
  # Implementation lookup
  defp get_implementation(function) do
    case FunctionRegistry.lookup_function(Accounting.Registry, function) do
      {:ok, implementation} -> implementation
      :error -> {__MODULE__, :"do_#{function}", :default}
    end
  end
  
  defp apply_implementation({module, function, :default}, args) do
    apply(module, :"do_#{function}", args)
  end
  
  defp apply_implementation({module, function, _}, args) do
    apply(module, function, args)
  end
  
  # Default implementation functions
  def do_calculate_tax(amount) do
    Decimal.mult(amount, Decimal.new("0.2"))
  end
  
  def do_apply_discount(amount, rate) do
    discount = Decimal.mult(amount, rate)
    Decimal.sub(amount, discount)
  end
end
```

To register an override for a specific region:

```elixir
# During application initialization
{:ok, registry} = FunctionRegistry.start_link(name: Accounting.Registry)

# Register a custom implementation
FunctionRegistry.register_function(
  Accounting.Registry,
  :calculate_tax,
  Accounting.BusinessLogic.US,
  :calculate_tax,
  1
)
```

## Ash Framework integration

### Resource-based architecture

Ash Framework's resource-oriented approach aligns perfectly with accounting domain entities:

```elixir
defmodule MyApp.Accounting.Account do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Account]
  
  postgres do
    table "accounts"
    repo MyApp.Repo
  end
  
  account do
    transfer_resource MyApp.Accounting.Transfer
    balance_resource MyApp.Accounting.Balance
    open_action_accept [:account_number]
  end
  
  attributes do
    uuid_primary_key :id
    attribute :account_number, :string do
      allow_nil? false
    end
    attribute :name, :string
    attribute :type, :atom, constraints: [one_of: [:asset, :liability, :equity, :revenue, :expense]]
    attribute :active, :boolean, default: true
  end
end
```

### CQRS and Event Sourcing with AshCommanded

AshCommanded extends Ash resources with CQRS and Event Sourcing capabilities:

```elixir
defmodule MyApp.Accounting.Account do
  use Ash.Resource,
    extensions: [AshCommanded.Commanded.Dsl]
  
  # Regular resource configurations...
  
  commanded do
    commands do
      command :credit_account do
        fields([:id, :amount])
        identity_field(:id)
        action :credit
      end
      
      command :debit_account do
        fields([:id, :amount])
        identity_field(:id)
        action :debit
      end
    end
    
    events do
      event :account_credited do
        fields([:id, :amount])
      end
      
      event :account_debited do
        fields([:id, :amount])
      end
    end
    
    projections do
      projection :account_credited do
        action(:update)
        changes(fn event, _changeset ->
          %{balance: event.amount}
        end)
      end
      
      projection :account_debited do
        action(:update)
        changes(fn event, _changeset ->
          %{balance: -event.amount}
        end)
      end
    end
  end
end
```

### Domain organization

For a modular accounting system, organize resources into distinct domains:

```elixir
defmodule MyApp.Accounting do
  use Ash.Domain
  
  resources do
    resource MyApp.Accounting.Account
    resource MyApp.Accounting.Balance
    resource MyApp.Accounting.Transfer
    resource MyApp.Accounting.JournalEntry
  end
end

defmodule MyApp.Reports do
  use Ash.Domain
  
  resources do
    resource MyApp.Reports.BalanceSheet
    resource MyApp.Reports.IncomeStatement
    resource MyApp.Reports.CashFlowStatement
  end
end
```

## Cross-module communication patterns

### Direct function calls

For modules that are always present, use direct function calls:

```elixir
# From Accounts Receivable calling General Ledger
def record_customer_payment(customer_id, amount, date) do
  # Local processing
  payment_data = process_payment(customer_id, amount, date)
  
  # Call to General Ledger to record the journal entry
  AccountingSystem.GeneralLedger.create_journal_entry(%{
    description: "Customer payment: #{customer_id}",
    date: date,
    entries: [
      %{account: "cash", type: :debit, amount: amount},
      %{account: "accounts_receivable", type: :credit, amount: amount}
    ]
  })
end
```

### Dynamic communication with optional modules

For optional modules, check availability before making calls:

```elixir
def generate_inventory_report(date_range) do
  if AccountingSystem.Registry.module_available?(:inventory) do
    AccountingSystem.Inventory.generate_report(date_range)
  else
    {:error, :inventory_module_not_available}
  end
end
```

### Event-based communication

For asynchronous interactions between modules, implement a PubSub system:

```elixir
defmodule AccountingSystem.PubSub do
  @registry_name :accounting_pubsub

  def start_link do
    Registry.start_link(keys: :duplicate, name: @registry_name)
  end

  def subscribe(topic) do
    Registry.register(@registry_name, topic, [])
    :ok
  end

  def publish(topic, message) do
    Registry.dispatch(@registry_name, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:accounting_event, topic, message})
    end)
    :ok
  end
end
```

Usage example:

```elixir
# In Accounts Receivable
def create_invoice(customer_id, amount, items) do
  # Create invoice
  invoice = %Invoice{id: invoice_id, customer_id: customer_id, amount: amount, items: items}
  
  # Publish event for other modules to react
  AccountingSystem.PubSub.publish(:invoice_created, invoice)
  
  {:ok, invoice}
end

# In Inventory module
def init do
  AccountingSystem.PubSub.subscribe(:invoice_created)
  # Other initialization
end

def handle_info({:accounting_event, :invoice_created, invoice}, state) do
  # Update inventory based on invoice
  update_inventory_for_invoice(invoice)
  {:noreply, state}
end
```

## Machine learning integration

### Integration hooks for ML/AI

Implement an event-driven architecture with hooks for ML processing:

```elixir
defmodule Accounting.MLHooks do
  # Hook into transaction creation
  def after_transaction_created(transaction) do
    # Asynchronously check for fraud/anomalies
    Task.start(fn -> 
      anomaly_score = Accounting.AnomalyDetection.check_transaction(transaction)
      if anomaly_score > threshold() do
        Accounting.Notifications.send_anomaly_alert(transaction, anomaly_score)
      end
    end)
    
    # Return transaction unchanged for the main flow
    transaction
  end
  
  # Hook into document upload
  def after_document_upload(document) do
    # Process document asynchronously
    Task.start(fn ->
      extracted_data = Accounting.DocumentProcessing.process_document(document)
      Accounting.DocumentRepository.update_with_extracted_data(document.id, extracted_data)
    end)
    
    # Return document unchanged for the main flow
    document
  end
end
```

### AshAi integration

AshAi extends Ash resources with AI capabilities:

```elixir
defmodule Accounting.Document do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi.Extension]
    
  attributes do
    uuid_primary_key :id
    attribute :content, :string
    attribute :embedded_vector, :vector, default: nil
  end
  
  ai do
    # Configure vector embeddings for document search
    embeddings do
      attribute :content
      vector_attribute :embedded_vector
      embedding_model MyApp.OpenAIEmbeddingModel
    end
  end
  
  actions do
    # Define action for semantic search
    read :search do
      argument :query, :string, allow_nil?: false
      prepare fn query, context ->
        case YourEmbeddingModel.generate([query.arguments.query], []) do
          {:ok, [search_vector]} -> 
            Ash.Query.filter(
              query, 
              vector_cosine_distance(embedded_vector, ^search_vector) < 0.5
            )
          {:error, error} -> {:error, error}
        end
      end
    end
  end
end
```

### Axon integration for fraud detection

```elixir
defmodule Accounting.FraudDetection do
  def create_model do
    # Create a binary classification model
    Axon.input("transaction", shape: {nil, feature_count})
    |> Axon.dense(256, activation: :relu)
    |> Axon.batch_norm()
    |> Axon.dense(128, activation: :relu)
    |> Axon.dropout(rate: 0.3)
    |> Axon.dense(64, activation: :relu)
    |> Axon.dense(1, activation: :sigmoid)
  end
  
  def train_model(model, training_data) do
    # Use class weights to handle imbalanced fraud data
    weights = calculate_class_weights(training_data)
    
    model
    |> Axon.Loop.trainer(:binary_cross_entropy, 
        Polaris.Optimizers.adam(learning_rate: 0.001),
        class_weights: weights)
    |> Axon.Loop.metric(:auc, "AUC")
    |> Axon.Loop.metric(:precision, "Precision")
    |> Axon.Loop.metric(:recall, "Recall")
    |> Axon.Loop.run(training_data, epochs: 20, compiler: EXLA)
  end
end
```

## Accounting domain-specific implementation

### Implementing double-entry accounting

Use AshDoubleEntry for implementing double-entry bookkeeping:

```elixir
defmodule MyApp.Accounting.Account do
  use Ash.Resource,
    domain: MyApp.Accounting,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Account]
  
  postgres do
    table "accounts"
    repo MyApp.Repo
  end
  
  account do
    transfer_resource MyApp.Accounting.Transfer
    balance_resource MyApp.Accounting.Balance
    open_action_accept [:account_number]
  end
  
  attributes do
    attribute :account_number, :string do
      allow_nil? false
    end

    ash_money_attribute :balance do
      default_currency "USD"
      allow_nil? false
      default 0
    end
  end
end

defmodule MyApp.Accounting.Transfer do
  use Ash.Resource,
    domain: MyApp.Accounting,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]
  
  postgres do
    table "transfers"
    repo MyApp.Repo
  end
  
  transfer do
    account_resource MyApp.Accounting.Account
    balance_resource MyApp.Accounting.Balance
  end
  
  attributes do
    ash_money_attribute :amount do
      allow_nil? false
    end
    
    attribute :description, :string
    attribute :reference_number, :string
  end
end
```

### Journal entry validation

Implement validation rules that enforce double-entry principles:

```elixir
defmodule Accounting.Validations do
  def balanced_entry(changeset) do
    with {:ok, entry_lines} <- Ash.Changeset.fetch_change(changeset, :entry_lines) do
      total = Enum.reduce(entry_lines, Decimal.new(0), fn line, acc ->
        case line.type do
          :debit -> Decimal.add(acc, line.amount)
          :credit -> Decimal.sub(acc, line.amount)
        end
      end)
      
      if Decimal.equal?(total, Decimal.new(0)) do
        :ok
      else
        {:error, "Journal entry must be balanced with equal debits and credits"}
      end
    else
      _ -> :ok # No changes to entry_lines
    end
  end
end
```

## Complete system implementation

### System Manager implementation

```elixir
defmodule AccountingSystem.SystemManager.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: :accounting_pubsub},
      AccountingSystem.SystemManager,
      AccountingSystem.FunctionRegistry
    ]

    opts = [strategy: :one_for_one, name: AccountingSystem.SystemManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### General Ledger module

```elixir
defmodule AccountingSystem.GeneralLedger do
  @moduledoc """
  General Ledger module for managing accounts, journal entries, and financial reporting.
  """
  
  alias AccountingSystem.GeneralLedger.{Account, JournalEntry, Reporting}
  
  # Account management
  def create_account(params) do
    Account.create(params)
  end
  
  def get_account(account_id) do
    Account.get(account_id)
  end
  
  # Journal entries
  def create_journal_entry(params) do
    JournalEntry.create(params)
  end
  
  def post_journal_entry(entry_id) do
    JournalEntry.post(entry_id)
  end
  
  # Financial reporting
  def generate_trial_balance(date) do
    Reporting.trial_balance(date)
  end
  
  def generate_income_statement(start_date, end_date) do
    Reporting.income_statement(start_date, end_date)
  end
  
  def generate_balance_sheet(date) do
    Reporting.balance_sheet(date)
  end
end
```

### Accounts Receivable module

```elixir
defmodule AccountingSystem.AccountsReceivable do
  @moduledoc """
  Accounts Receivable module for managing customer invoices and payments.
  """
  
  alias AccountingSystem.AccountsReceivable.{Customer, Invoice, Payment}
  alias AccountingSystem.GeneralLedger
  
  # Customer management
  def create_customer(params) do
    Customer.create(params)
  end
  
  # Invoice management
  def create_invoice(params) do
    with {:ok, invoice} <- Invoice.create(params),
         :ok <- create_accounting_entry(invoice) do
      {:ok, invoice}
    end
  end
  
  # Payment processing
  def record_payment(params) do
    with {:ok, payment} <- Payment.create(params),
         :ok <- process_payment_accounting(payment) do
      {:ok, payment}
    end
  end
  
  # Private functions
  defp create_accounting_entry(invoice) do
    GeneralLedger.create_journal_entry(%{
      description: "Invoice ##{invoice.number} for #{invoice.customer_name}",
      date: invoice.date,
      entries: [
        %{account: "accounts_receivable", type: :debit, amount: invoice.total},
        %{account: "sales_revenue", type: :credit, amount: invoice.total}
      ]
    })
  end
  
  defp process_payment_accounting(payment) do
    GeneralLedger.create_journal_entry(%{
      description: "Payment for Invoice ##{payment.invoice_number}",
      date: payment.date,
      entries: [
        %{account: "cash", type: :debit, amount: payment.amount},
        %{account: "accounts_receivable", type: :credit, amount: payment.amount}
      ]
    })
  end
end
```

## Deployment strategies

### Single-node deployment

Deploy the entire umbrella application as a single release:

```elixir
# In mix.exs at umbrella root
def project do
  [
    apps_path: "apps",
    releases: [
      accounting_system: [
        include_executables_for: [:unix],
        applications: [
          system_manager: :permanent,
          general_ledger: :permanent,
          accounts_receivable: :permanent,
          accounts_payable: :permanent,
          inventory: :permanent,
          sales_orders: :permanent,
          purchasing: :permanent
        ]
      ]
    ]
  ]
end
```

### Multi-node deployment

For larger systems, create multiple releases for different parts of the system:

```elixir
# In mix.exs at umbrella root
def project do
  [
    apps_path: "apps",
    releases: [
      # Core accounting functions
      accounting_core: [
        include_executables_for: [:unix],
        applications: [
          system_manager: :permanent,
          general_ledger: :permanent,
          accounts_receivable: :permanent,
          accounts_payable: :permanent
        ]
      ],
      # Inventory and sales functions
      inventory_sales: [
        include_executables_for: [:unix],
        applications: [
          system_manager: :permanent,
          inventory: :permanent,
          sales_orders: :permanent,
          purchasing: :permanent
        ]
      ]
    ]
  ]
end
```

## Conclusion

Building a modular accounting system with Elixir and the Ash Framework provides a powerful, flexible foundation for financial applications. The combination of umbrella applications, the System Manager pattern, ETS-based function overrides, and CQRS/Event Sourcing via AshCommanded creates an architecture that is both modular and robust.

Key advantages of this approach include:

1. **Modularity** - Each accounting function is a separate application that can be developed, tested, and deployed independently.

2. **Extensibility** - New modules can be added without modifying existing code.

3. **Customizability** - Business logic can be customized via ETS-based function overrides without changing core code.

4. **Auditability** - Event Sourcing provides a complete audit trail of all system changes.

5. **ML/AI Integration** - Hooks for machine learning allow for fraud detection, anomaly detection, and other AI-powered features.

By following these patterns and leveraging the full power of Elixir's ecosystem, you can create an accounting system that is both technically sophisticated and adaptable to changing business requirements.