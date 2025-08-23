I'll analyze the AccountMate AR data dictionary and create an Ash domain structure with semantically correct naming conventions. Let me design the domain and resources based on the document provided.

# Accountex Accounts Receivable Domain

## Domain Module

```elixir
defmodule Accountex.AccountsReceivable do
  use Ash.Domain
  
  alias Accountex.AccountsReceivable.{
    Customer,
    CustomerAddress,
    CustomerContact,
    CustomerCreditCard,
    CustomerActivity,
    Invoice,
    InvoiceLineItem,
    InvoiceRemark,
    Payment,
    PaymentApplication,
    Salesperson,
    RevenueCategory,
    PaymentTerm,
    FreightCode,
    RecurringInvoice,
    RecurringInvoiceLineItem,
    FinanceCharge,
    BankDeposit,
    OpenCreditAdjustment,
    TaxCode
  }

  resources do
    resource Customer
    resource CustomerAddress
    resource CustomerContact
    resource CustomerCreditCard
    resource CustomerActivity
    resource Invoice
    resource InvoiceLineItem
    resource InvoiceRemark
    resource Payment
    resource PaymentApplication
    resource Salesperson
    resource RevenueCategory
    resource PaymentTerm
    resource FreightCode
    resource RecurringInvoice
    resource RecurringInvoiceLineItem
    resource FinanceCharge
    resource BankDeposit
    resource OpenCreditAdjustment
    resource TaxCode
  end

  # Code interfaces for Customer operations
  def customers do
    Customer
  end

  def create_customer(params) do
    Customer
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create()
  end

  def update_customer(customer, params) do
    customer
    |> Ash.Changeset.for_update(:update, params)
    |> Ash.update()
  end

  def list_customers(opts \\ []) do
    Customer
    |> Ash.Query.new()
    |> Ash.read(opts)
  end

  def get_customer(id) do
    Customer
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  # Code interfaces for Invoice operations
  def invoices do
    Invoice
  end

  def create_invoice(params) do
    Invoice
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create()
  end

  def update_invoice(invoice, params) do
    invoice
    |> Ash.Changeset.for_update(:update, params)
    |> Ash.update()
  end

  def list_invoices(opts \\ []) do
    Invoice
    |> Ash.Query.new()
    |> Ash.read(opts)
  end

  def get_invoice(id) do
    Invoice
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  def void_invoice(invoice) do
    invoice
    |> Ash.Changeset.for_update(:void)
    |> Ash.update()
  end

  # Code interfaces for Payment operations
  def payments do
    Payment
  end

  def create_payment(params) do
    Payment
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create()
  end

  def apply_payment(payment, invoice, params) do
    PaymentApplication
    |> Ash.Changeset.for_create(:create, Map.merge(params, %{
      payment_id: payment.id,
      invoice_id: invoice.id
    }))
    |> Ash.create()
  end

  def void_payment(payment) do
    payment
    |> Ash.Changeset.for_update(:void)
    |> Ash.update()
  end

  # Additional code interfaces would follow similar patterns for other resources
end
```

## Core Resources

### Customer Resource

```elixir
defmodule Accountex.AccountsReceivable.Customer do
  use Ash.Resource,
    domain: Accountex.AccountsReceivable,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "customers"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id, type: :uuid_v7
    
    attribute :customer_number, :string do
      allow_nil? false
      public? true
    end

    attribute :company_name, :string do
      allow_nil? false
      public? true
    end

    attribute :company_alias, :string, public?: true
    
    attribute :primary_address_line_1, :string, public?: true
    attribute :primary_address_line_2, :string, public?: true
    attribute :primary_city, :string, public?: true
    attribute :primary_state, :string, public?: true
    attribute :primary_postal_code, :string, public?: true
    attribute :primary_country, :string, public?: true
    
    attribute :primary_phone_number, :string, public?: true
    attribute :secondary_phone_number, :string, public?: true
    attribute :fax_number, :string, public?: true
    attribute :email_address, :string, public?: true
    attribute :website_url, :string, public?: true
    
    attribute :contact_first_name, :string, public?: true
    attribute :contact_last_name, :string, public?: true
    attribute :contact_title, :string, public?: true
    attribute :contact_salutation, :string, public?: true
    
    attribute :customer_status, :atom do
      constraints one_of: [:active, :inactive, :on_hold]
      default :active
      public? true
    end
    
    attribute :customer_classification, :string, public?: true
    attribute :industry_type, :string, public?: true
    attribute :sales_territory, :string, public?: true
    
    attribute :federal_tax_id, :string, public?: true
    attribute :currency_code, :string, default: "USD", public?: true
    
    attribute :credit_limit_amount, :decimal, default: 0, public?: true
    attribute :temporary_credit_increase_amount, :decimal, default: 0, public?: true
    attribute :temporary_credit_valid_until, :date, public?: true
    
    attribute :year_to_date_sales_amount, :decimal, default: 0, public?: true
    attribute :all_time_sales_amount, :decimal, default: 0, public?: true
    attribute :outstanding_balance_amount, :decimal, default: 0, public?: true
    attribute :open_credit_amount, :decimal, default: 0, public?: true
    
    attribute :average_payment_days, :integer, public?: true
    attribute :last_sale_date, :date, public?: true
    attribute :last_payment_date, :date, public?: true
    attribute :last_payment_amount, :decimal, public?: true
    
    attribute :apply_finance_charges, :boolean, default: false, public?: true
    attribute :print_statements, :boolean, default: true, public?: true
    attribute :consolidate_statements, :boolean, default: false, public?: true
    
    attribute :require_purchase_order, :boolean, default: false, public?: true
    attribute :check_duplicate_purchase_order, :boolean, default: false, public?: true
    
    attribute :customer_since_date, :utc_datetime_usec, public?: true
    
    timestamps()
  end

  relationships do
    belongs_to :assigned_salesperson, Accountex.AccountsReceivable.Salesperson do
      public? true
    end

    belongs_to :payment_term, Accountex.AccountsReceivable.PaymentTerm do
      public? true
    end

    belongs_to :revenue_category, Accountex.AccountsReceivable.RevenueCategory do
      public? true
    end

    belongs_to :parent_customer, Accountex.AccountsReceivable.Customer do
      public? true
    end

    belongs_to :default_warehouse, Accountex.Inventory.Warehouse do
      public? true
    end

    belongs_to :tax_code, Accountex.AccountsReceivable.TaxCode do
      public? true
    end

    has_many :customer_addresses, Accountex.AccountsReceivable.CustomerAddress do
      public? true
    end

    has_many :customer_contacts, Accountex.AccountsReceivable.CustomerContact do
      public? true
    end

    has_many :customer_credit_cards, Accountex.AccountsReceivable.CustomerCreditCard do
      public? true
    end

    has_many :invoices, Accountex.AccountsReceivable.Invoice do
      public? true
    end

    has_many :payments, Accountex.AccountsReceivable.Payment do
      public? true
    end

    has_many :customer_activities, Accountex.AccountsReceivable.CustomerActivity do
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:customer_number, :company_name, :company_alias, :primary_address_line_1,
              :primary_address_line_2, :primary_city, :primary_state, :primary_postal_code,
              :primary_country, :contact_first_name, :contact_last_name, :email_address,
              :credit_limit_amount, :currency_code, :customer_classification]
    end

    update :update do
      primary? true
      accept [:company_name, :company_alias, :primary_address_line_1, :primary_address_line_2,
              :primary_city, :primary_state, :primary_postal_code, :primary_country,
              :email_address, :credit_limit_amount, :customer_status, :apply_finance_charges]
    end

    update :update_credit_limit do
      accept [:credit_limit_amount, :temporary_credit_increase_amount, :temporary_credit_valid_until]
    end

    update :put_on_hold do
      change set_attribute(:customer_status, :on_hold)
    end

    update :activate do
      change set_attribute(:customer_status, :active)
    end
  end

  validations do
    validate string_length(:customer_number, max: 10)
    validate string_length(:company_name, max: 40)
    validate string_length(:email_address, max: 255)
    validate compare(:credit_limit_amount, greater_than_or_equal_to: 0)
  end
end
```

### Invoice Resource

```elixir
defmodule Accountex.AccountsReceivable.Invoice do
  use Ash.Resource,
    domain: Accountex.AccountsReceivable,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "invoices"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id, type: :uuid_v7
    
    attribute :invoice_number, :string do
      allow_nil? false
      public? true
    end

    attribute :invoice_type, :atom do
      constraints one_of: [:standard, :credit_memo, :debit_memo, :finance_charge]
      default :standard
      public? true
    end

    attribute :invoice_date, :date do
      allow_nil? false
      public? true
    end

    attribute :due_date, :date do
      allow_nil? false
      public? true
    end

    attribute :discount_date, :date, public?: true
    
    attribute :customer_purchase_order_number, :string, public?: true
    attribute :sales_order_number, :string, public?: true
    attribute :shipment_number, :string, public?: true
    attribute :original_invoice_number, :string, public?: true
    
    # Billing Address Fields
    attribute :billing_company_name, :string, public?: true
    attribute :billing_address_line_1, :string, public?: true
    attribute :billing_address_line_2, :string, public?: true
    attribute :billing_city, :string, public?: true
    attribute :billing_state, :string, public?: true
    attribute :billing_postal_code, :string, public?: true
    attribute :billing_country, :string, public?: true
    attribute :billing_contact_name, :string, public?: true
    attribute :billing_phone_number, :string, public?: true
    attribute :billing_email_address, :string, public?: true
    
    # Shipping Address Fields
    attribute :shipping_company_name, :string, public?: true
    attribute :shipping_address_line_1, :string, public?: true
    attribute :shipping_address_line_2, :string, public?: true
    attribute :shipping_city, :string, public?: true
    attribute :shipping_state, :string, public?: true
    attribute :shipping_postal_code, :string, public?: true
    attribute :shipping_country, :string, public?: true
    attribute :shipping_contact_name, :string, public?: true
    attribute :shipping_phone_number, :string, public?: true
    attribute :shipping_email_address, :string, public?: true
    
    attribute :shipping_method, :string, public?: true
    attribute :freight_on_board_point, :string, public?: true
    
    attribute :currency_code, :string, default: "USD", public?: true
    attribute :exchange_rate, :decimal, default: 1.0, public?: true
    
    # Financial Amounts
    attribute :subtotal_amount, :decimal, default: 0, public?: true
    attribute :discount_amount, :decimal, default: 0, public?: true
    attribute :freight_amount, :decimal, default: 0, public?: true
    attribute :tax_amount_1, :decimal, default: 0, public?: true
    attribute :tax_amount_2, :decimal, default: 0, public?: true
    attribute :tax_amount_3, :decimal, default: 0, public?: true
    attribute :adjustment_amount, :decimal, default: 0, public?: true
    attribute :finance_charge_amount, :decimal, default: 0, public?: true
    
    attribute :total_paid_amount, :decimal, default: 0, public?: true
    attribute :total_discount_taken_amount, :decimal, default: 0, public?: true
    attribute :total_adjustment_amount, :decimal, default: 0, public?: true
    attribute :total_writeoff_amount, :decimal, default: 0, public?: true
    attribute :outstanding_balance_amount, :decimal, default: 0, public?: true
    
    # Foreign Currency Amounts
    attribute :foreign_subtotal_amount, :decimal, default: 0, public?: true
    attribute :foreign_discount_amount, :decimal, default: 0, public?: true
    attribute :foreign_freight_amount, :decimal, default: 0, public?: true
    attribute :foreign_tax_amount_1, :decimal, default: 0, public?: true
    attribute :foreign_tax_amount_2, :decimal, default: 0, public?: true
    attribute :foreign_tax_amount_3, :decimal, default: 0, public?: true
    attribute :foreign_outstanding_balance, :decimal, default: 0, public?: true
    
    attribute :terms_discount_percentage, :decimal, public?: true
    attribute :terms_discount_days, :integer, public?: true
    attribute :terms_net_days, :integer, public?: true
    
    attribute :invoice_printed, :boolean, default: false, public?: true
    attribute :packing_slip_printed, :boolean, default: false, public?: true
    attribute :posted_to_general_ledger, :boolean, default: false, public?: true
    attribute :is_void, :boolean, default: false, public?: true
    attribute :closed_date, :date, public?: true
    attribute :last_payment_date, :date, public?: true
    
    attribute :apply_taxes, :boolean, default: true, public?: true
    attribute :prices_include_tax, :boolean, default: false, public?: true
    attribute :apply_finance_charges, :boolean, default: true, public?: true
    
    timestamps()
  end

  relationships do
    belongs_to :customer, Accountex.AccountsReceivable.Customer do
      allow_nil? false
      public? true
    end

    belongs_to :salesperson, Accountex.AccountsReceivable.Salesperson do
      public? true
    end

    belongs_to :payment_term, Accountex.AccountsReceivable.PaymentTerm do
      public? true
    end

    belongs_to :freight_code, Accountex.AccountsReceivable.FreightCode do
      public? true
    end

    belongs_to :tax_code, Accountex.AccountsReceivable.TaxCode do
      public? true
    end

    belongs_to :warehouse, Accountex.Inventory.Warehouse do
      public? true
    end

    has_many :invoice_line_items, Accountex.AccountsReceivable.InvoiceLineItem do
      public? true
    end

    has_many :payment_applications, Accountex.AccountsReceivable.PaymentApplication do
      public? true
    end

    has_many :finance_charges, Accountex.AccountsReceivable.FinanceCharge do
      public? true
    end

    has_one :invoice_remark, Accountex.AccountsReceivable.InvoiceRemark do
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:invoice_number, :invoice_type, :invoice_date, :due_date, :customer_purchase_order_number,
              :billing_company_name, :billing_address_line_1, :shipping_company_name, 
              :shipping_address_line_1, :currency_code, :exchange_rate]
    end

    update :update do
      primary? true
      accept [:due_date, :discount_date, :customer_purchase_order_number, :shipping_method,
              :freight_amount, :adjustment_amount]
    end

    update :void do
      change set_attribute(:is_void, true)
      change set_attribute(:outstanding_balance_amount, 0)
    end

    update :post_to_general_ledger do
      change set_attribute(:posted_to_general_ledger, true)
    end

    update :mark_printed do
      change set_attribute(:invoice_printed, true)
    end
  end

  validations do
    validate string_length(:invoice_number, max: 10)
    validate compare(:outstanding_balance_amount, greater_than_or_equal_to: 0)
  end

  calculations do
    calculate :total_amount, :decimal do
      calculation fn invoice, _context ->
        invoice.subtotal_amount
        |> Decimal.sub(invoice.discount_amount)
        |> Decimal.add(invoice.freight_amount)
        |> Decimal.add(invoice.tax_amount_1)
        |> Decimal.add(invoice.tax_amount_2)
        |> Decimal.add(invoice.tax_amount_3)
        |> Decimal.add(invoice.adjustment_amount)
        |> Decimal.add(invoice.finance_charge_amount)
      end
    end

    calculate :is_past_due, :boolean do
      calculation fn invoice, _context ->
        Date.compare(Date.utc_today(), invoice.due_date) == :gt && 
        invoice.outstanding_balance_amount > 0
      end
    end
  end
end
```

### Payment Resource

```elixir
defmodule Accountex.AccountsReceivable.Payment do
  use Ash.Resource,
    domain: Accountex.AccountsReceivable,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payments"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id, type: :uuid_v7
    
    attribute :receipt_number, :string do
      allow_nil? false
      public? true
    end

    attribute :payment_date, :date do
      allow_nil? false
      public? true
    end

    attribute :last_application_date, :date, public?: true
    
    attribute :payment_method, :atom do
      constraints one_of: [:cash, :check, :credit_card, :ach, :wire, :other]
      default :check
      public? true
    end

    attribute :check_or_card_number, :string, public?: true
    attribute :payment_reference, :string, public?: true
    
    attribute :currency_code, :string, default: "USD", public?: true
    attribute :exchange_rate, :decimal, default: 1.0, public?: true
    
    attribute :payment_amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :applied_amount, :decimal, default: 0, public?: true
    attribute :unapplied_amount, :decimal, default: 0, public?: true
    
    attribute :foreign_payment_amount, :decimal, public?: true
    attribute :foreign_applied_amount, :decimal, default: 0, public?: true
    
    attribute :bank_deposit_amount, :decimal, public?: true
    
    attribute :is_void, :boolean, default: false, public?: true
    attribute :posted_to_general_ledger, :boolean, default: false, public?: true
    attribute :receipt_printed, :boolean, default: false, public?: true
    
    attribute :entered_by_user, :string, public?: true
    
    timestamps()
  end

  relationships do
    belongs_to :customer, Accountex.AccountsReceivable.Customer do
      allow_nil? false
      public? true
    end

    belongs_to :payment_term, Accountex.AccountsReceivable.PaymentTerm do
      public? true
    end

    belongs_to :bank_account, Accountex.Banking.BankAccount do
      public? true
    end

    belongs_to :bank_deposit, Accountex.AccountsReceivable.BankDeposit do
      public? true
    end

    has_many :payment_applications, Accountex.AccountsReceivable.PaymentApplication do
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:receipt_number, :payment_date, :payment_method, :check_or_card_number,
              :payment_reference, :currency_code, :exchange_rate, :payment_amount]
    end

    update :update do
      primary? true
      accept [:payment_reference, :bank_deposit_amount]
    end

    update :void do
      change set_attribute(:is_void, true)
    end

    update :post_to_general_ledger do
      change set_attribute(:posted_to_general_ledger, true)
    end
  end

  validations do
    validate string_length(:receipt_number, max: 10)
    validate compare(:payment_amount, greater_than: 0)
  end

  calculations do
    calculate :unapplied_amount, :decimal do
      calculation fn payment, _context ->
        Decimal.sub(payment.payment_amount, payment.applied_amount)
      end
    end
  end
end
```

## Supporting Resources

### PaymentApplication Resource

```elixir
defmodule Accountex.AccountsReceivable.PaymentApplication do
  use Ash.Resource,
    domain: Accountex.AccountsReceivable,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payment_applications"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id, type: :uuid_v7
    
    attribute :application_date, :date do
      allow_nil? false
      public? true
    end

    attribute :applied_amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :discount_taken_amount, :decimal, default: 0, public?: true
    attribute :adjustment_amount, :decimal, default: 0, public?: true
    attribute :writeoff_amount, :decimal, default: 0, public?: true
    attribute :tax_claimback_amount, :decimal, default: 0, public?: true
    
    attribute :foreign_applied_amount, :decimal, public?: true
    attribute :foreign_discount_taken_amount, :decimal, default: 0, public?: true
    attribute :foreign_adjustment_amount, :decimal, default: 0, public?: true
    attribute :foreign_writeoff_amount, :decimal, default: 0, public?: true
    
    attribute :multicurrency_variance_amount, :decimal, default: 0, public?: true
    
    attribute :is_void, :boolean, default: false, public?: true
    attribute :posted_to_general_ledger, :boolean, default: false, public?: true
    
    timestamps()
  end

  relationships do
    belongs_to :payment, Accountex.AccountsReceivable.Payment do
      allow_nil? false
      public? true
    end

    belongs_to :invoice, Accountex.AccountsReceivable.Invoice do
      allow_nil? false
      public? true
    end

    belongs_to :customer, Accountex.AccountsReceivable.Customer do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:application_date, :applied_amount, :discount_taken_amount, 
              :adjustment_amount, :writeoff_amount]
    end

    update :void do
      change set_attribute(:is_void, true)
    end
  end

  validations do
    validate compare(:applied_amount, greater_than: 0)
  end
end
```

## Domain Diagram

```mermaid
erDiagram
    Customer ||--o{ CustomerAddress : has
    Customer ||--o{ CustomerContact : has
    Customer ||--o{ CustomerCreditCard : has
    Customer ||--o{ CustomerActivity : has
    Customer ||--o{ Invoice : receives
    Customer ||--o{ Payment : makes
    Customer ||--o{ RecurringInvoice : has
    Customer }o--|| Salesperson : assigned_to
    Customer }o--|| PaymentTerm : uses
    Customer }o--|| RevenueCategory : categorized_as
    Customer }o--|| Customer : child_of
    
    Invoice ||--o{ InvoiceLineItem : contains
    Invoice ||--o{ PaymentApplication : receives
    Invoice ||--o{ FinanceCharge : accrues
    Invoice ||--o| InvoiceRemark : has
    Invoice }o--|| Customer : billed_to
    Invoice }o--|| Salesperson : sold_by
    Invoice }o--|| PaymentTerm : uses
    Invoice }o--|| FreightCode : uses
    Invoice }o--|| TaxCode : uses
    
    Payment ||--o{ PaymentApplication : applied_to
    Payment }o--|| Customer : from
    Payment }o--|| PaymentTerm : uses
    Payment }o--|| BankDeposit : included_in
    
    PaymentApplication }o--|| Payment : from
    PaymentApplication }o--|| Invoice : to
    PaymentApplication }o--|| Customer : for
    
    RecurringInvoice ||--o{ RecurringInvoiceLineItem : contains
    RecurringInvoice }o--|| Customer : for
    RecurringInvoice }o--|| Salesperson : assigned_to
    RecurringInvoice }o--|| PaymentTerm : uses
    
    InvoiceLineItem }o--|| Invoice : part_of
    InvoiceLineItem }o--|| RevenueCategory : categorized_as
    
    RecurringInvoiceLineItem }o--|| RecurringInvoice : part_of
    RecurringInvoiceLineItem }o--|| RevenueCategory : categorized_as
    
    Salesperson ||--o{ Customer : manages
    Salesperson ||--o{ Invoice : created
    Salesperson }o--|| RevenueCategory : uses
    
    RevenueCategory ||--o{ Customer : default_for
    RevenueCategory ||--o{ InvoiceLineItem : categorizes
    
    PaymentTerm ||--o{ Customer : default_for
    PaymentTerm ||--o{ Invoice : applied_to
    PaymentTerm ||--o{ Payment : used_by
    
    FreightCode ||--o{ Invoice : applied_to
    
    TaxCode ||--o{ Customer : default_for
    TaxCode ||--o{ Invoice : applied_to
    
    FinanceCharge }o--|| Invoice : applied_to
    FinanceCharge }o--|| Customer : charged_to
    
    BankDeposit ||--o{ Payment : includes
    
    OpenCreditAdjustment }o--|| Customer : for
```

## Additional Resources Configuration

The remaining resources would follow similar patterns:

- **CustomerAddress**: Manages multiple addresses per customer
- **CustomerContact**: Manages multiple contacts per customer  
- **CustomerCreditCard**: Stores payment card information
- **CustomerActivity**: Tracks customer interactions and activities
- **InvoiceLineItem**: Individual line items on invoices
- **InvoiceRemark**: Comments and notes on invoices
- **Salesperson**: Sales team member information
- **RevenueCategory**: Revenue classification codes
- **PaymentTerm**: Payment terms and conditions
- **FreightCode**: Freight charge definitions
- **RecurringInvoice**: Templates for recurring invoices
- **RecurringInvoiceLineItem**: Line items for recurring invoices
- **FinanceCharge**: Finance charges applied to past-due invoices
- **BankDeposit**: Bank deposit records
- **OpenCreditAdjustment**: Credit adjustments and refunds
- **TaxCode**: Sales tax configurations

Each resource would include:
- Proper UUID7 primary keys
- Semantically named fields in snake_case
- Appropriate relationships using foreign keys
- Standard CRUD actions
- Business-specific actions (void, post_to_gl, etc.)
- Validations based on business rules
- Calculations for derived values

This structure provides a clean, maintainable Ash domain that maps to the AccountMate AR system while following Elixir and Ash best practices.