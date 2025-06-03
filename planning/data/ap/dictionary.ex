# Vendor Resource (Apvend table)
defmodule AccountMate.AP.Vendor do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apvend"
    repo AccountMate.Repo
  end

  attributes do
    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :company, :string do
      constraints max_length: 40
      allow_nil? false
    end

    attribute :company2, :string do
      constraints max_length: 40
      description "Alias"
    end

    attribute :addr1, :string do
      constraints max_length: 40
      description "Address 1"
    end

    attribute :addr2, :string do
      constraints max_length: 40
      description "Address 2"
    end

    attribute :city, :string do
      constraints max_length: 20
    end

    attribute :state, :string do
      constraints max_length: 15
    end

    attribute :zip, :string do
      constraints max_length: 10
      description "ZIP Code"
    end

    attribute :country, :string do
      constraints max_length: 25
    end

    attribute :phone1, :string do
      constraints max_length: 20
      description "Phone 1"
    end

    attribute :phone2, :string do
      constraints max_length: 20
      description "Phone 2"
    end

    attribute :fax, :string do
      constraints max_length: 20
    end

    attribute :email, :string do
      constraints max_length: 250
      description "E-mail Address"
    end

    attribute :website, :string do
      constraints max_length: 250
    end

    attribute :first_name, :string do
      constraints max_length: 15
    end

    attribute :last_name, :string do
      constraints max_length: 15
    end

    attribute :dear, :string do
      constraints max_length: 15
    end

    attribute :title, :string do
      constraints max_length: 20
    end

    attribute :buyer, :string do
      constraints max_length: 10
    end

    attribute :confirm_to, :string do
      constraints max_length: 30
    end

    attribute :tax_field1, :string do
      constraints max_length: 50
      description "Tax Field 1"
    end

    attribute :ap_account_id, :string do
      constraints max_length: 30
      description "Accounts Payable G/L Account ID"
      allow_nil? false
    end

    attribute :prepayment_account, :string do
      constraints max_length: 30
      description "Prepayment Account"
      allow_nil? false
    end

    attribute :deferred_expense_account, :string do
      constraints max_length: 30
      description "Deferred Expense Account"
    end

    attribute :order_address_no, :string do
      constraints max_length: 10
      description "Order Address"
    end

    attribute :status, :string do
      constraints max_length: 1
      default "A"
      description "A - Active, I - Inactive, T - Temporary, O - One-Time Vendor"
    end

    attribute :pay_code, :string do
      constraints max_length: 10
      description "Pay Code (Terms)"
    end

    attribute :payment_type_1099, :string do
      constraints max_length: 1
      default "0"
      description "1099 Payment Type"
    end

    attribute :class, :string do
      constraints max_length: 10
    end

    attribute :industry, :string do
      constraints max_length: 10
    end

    attribute :payment_urgency, :string do
      constraints max_length: 1
      default "1"
    end

    attribute :check_memo, :string do
      constraints max_length: 35
    end

    attribute :pay_to_no, :string do
      constraints max_length: 10
      description "Factor (Pay To)"
    end

    attribute :bank_no, :string do
      constraints max_length: 10
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :reference, :string do
      constraints max_length: 20
    end

    attribute :vendor_customer_no, :string do
      constraints max_length: 20
      allow_nil? false
    end

    attribute :last_payment_no, :string do
      constraints max_length: 20
    end

    attribute :last_source_no, :string do
      constraints max_length: 10
    end

    attribute :sales_tax_code, :string do
      constraints max_length: 10
    end

    attribute :credit_card_no, :string do
      constraints max_length: 50
    end

    attribute :language, :string do
      constraints max_length: 3
      description "Vendor Language"
    end

    attribute :prenote, :string do
      constraints max_length: 1
      description "P - Require Pre-notification, C - Pre-notification Confirmed"
    end

    attribute :bank_name, :string do
      constraints max_length: 35
    end

    attribute :bank_account, :string do
      constraints max_length: 20
      description "Bank Account #"
    end

    attribute :bank_account_type, :string do
      constraints max_length: 1
    end

    attribute :bank_route, :string do
      constraints max_length: 9
      description "Bank Route #"
    end

    attribute :last_payment_type, :string do
      constraints max_length: 10
    end

    attribute :ship_via, :string do
      constraints max_length: 10
    end

    attribute :fob, :string do
      constraints max_length: 10
      description "F.O.B."
    end

    # Date fields
    attribute :last_payment_date, :date
    attribute :ytd_start_date, :date
    attribute :ytd_recalc_date, :date
    attribute :prenote_date, :date

    # Boolean fields
    attribute :credit_card_vendor, :boolean, default: false
    attribute :automatically_apply_full_payment, :boolean, default: false
    attribute :hold_apply_payment, :boolean, default: false
    attribute :require_po_no, :boolean, default: false
    attribute :verify_po_no, :boolean, default: false
    attribute :use_authorized_reference_accounts_only, :boolean, default: false
    attribute :hold_print_check, :boolean, default: false
    attribute :suppress_check_stub, :boolean, default: false
    attribute :one_check_per_invoice, :boolean, default: false
    attribute :record_accrued_received_goods, :boolean, default: false
    attribute :enable_export_po, :boolean, default: false
    attribute :use_vendor_part_no_for_po_entry, :boolean, default: false
    attribute :accept_inventory_item_no, :boolean, default: false
    attribute :print_item_no_in_po, :boolean, default: false
    attribute :use_last_received_cost, :boolean, default: false
    attribute :apply_tax, :boolean, default: false
    attribute :show_cost_with_tax, :boolean, default: false
    attribute :electronic_payment, :boolean, default: false
    attribute :ap_po_matching, :boolean, default: false
    attribute :show_notepad_first, :boolean, default: false
    attribute :require_bank_no, :boolean, default: false

    # Numeric fields
    attribute :atd_purchase_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :ytd_purchase_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :credit_limit, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :max_check_amount, :decimal, constraints: [precision: 18, scale: 4], default: 1000000
    attribute :balance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :open_debit_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :last_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :po_backorder_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_rate, :decimal, constraints: [precision: 5, scale: 2], default: 0
    attribute :expire_days, :integer, default: 0

    # Text fields
    attribute :export_po_fields, :string
    attribute :export_po_details_fields, :string

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    has_many :invoices, AccountMate.AP.Invoice do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :checks, AccountMate.AP.Check do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :addresses, AccountMate.AP.VendorAddress do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :contacts, AccountMate.AP.VendorContact do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :activities, AccountMate.AP.VendorActivity do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end

  identities do
    identity :unique_vendor_no, [:vendor_no]
  end
end

# Invoice Resource (Apinvc table)
defmodule AccountMate.AP.Invoice do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apinvc"
    repo AccountMate.Repo
  end

  attributes do
    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :invoice_no, :string do
      constraints max_length: 20
      allow_nil? false
      primary_key? true
    end

    attribute :po_no, :string do
      constraints max_length: 10
      description "PO #"
    end

    attribute :receipt_no, :string do
      constraints max_length: 10
      description "Receipt #"
    end

    attribute :reference, :string do
      constraints max_length: 20
    end

    attribute :description, :string do
      constraints max_length: 35
    end

    attribute :payment_type_1099, :string do
      constraints max_length: 1
      description "1099 Payment Type"
    end

    attribute :payment_urgency, :string do
      constraints max_length: 1
      default "1"
    end

    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :entered_by, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :type, :string do
      constraints max_length: 1
      description "'' - Regular Invoice, B - Open Balance, D - Debit Invoice, C - Credit Card Invoice, E - Deferred Expense Invoice"
    end

    attribute :voucher_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :sales_tax_code, :string do
      constraints max_length: 10
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    # Date fields
    attribute :invoice_date, :date, allow_nil? false
    attribute :due_date, :date, allow_nil? false
    attribute :discount_date, :date, allow_nil? false
    attribute :last_finance_charge_date, :date
    attribute :last_paid_date, :date
    attribute :closed_date, :date

    # Boolean fields
    attribute :hold, :boolean, default: false
    attribute :allow_tax_claim_back1, :boolean, default: false
    attribute :allow_tax_claim_back2, :boolean, default: false

    # Numeric fields - Home Currency
    attribute :non_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :invoice_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_prepayment, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :non_payment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :used_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :committed_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :committed_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :committed_withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :multicurrency_variance_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :multicurrency_rounding_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :gl_multicurrency_rounding_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :balance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :last_finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0

    # Foreign Currency amounts
    attribute :foreign_non_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_invoice_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_applied_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_applied_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_applied_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_applied_withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_applied_prepayment, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_non_payment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_used_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_committed_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_committed_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_committed_withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_balance, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_last_finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0

    attribute :exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1, allow_nil? false

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :distributions, AccountMate.AP.InvoiceDistribution do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end

    has_many :applied_payments, AccountMate.AP.AppliedPayment do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end
  end

  identities do
    identity :unique_vendor_invoice, [:vendor_no, :invoice_no]
  end
end

# Invoice Distribution Resource (Apdist table)
defmodule AccountMate.AP.InvoiceDistribution do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apdist"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :invoice_no, :string do
      constraints max_length: 20
      allow_nil? false
    end

    attribute :gl_account_id, :string do
      constraints max_length: 30
      description "GL Distribution Account"
      allow_nil? false
    end

    attribute :amortized_expense_account, :string do
      constraints max_length: 30
      description "Amortized Expense Account"
    end

    attribute :amortization_method, :string do
      constraints max_length: 1
      description "L - Straight-Line, S - Specific"
    end

    attribute :amortization_recurring_cycle, :string do
      constraints max_length: 1
      description "W - Weekly, M - Monthly, B - Bimonthly, Q - Quarterly, S - Semi-Annually, A - Annually"
    end

    attribute :type, :string do
      constraints max_length: 2
      description "P - Accounts Payable, N - Nonpayment, D - Prepayment, F - Finance Charge, R - Expense Account, etc."
    end

    attribute :old_type, :string do
      constraints max_length: 2
      description "Old Type"
    end

    attribute :description, :string do
      constraints max_length: 40
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :tax_claim_code, :string do
      constraints max_length: 1
    end

    attribute :receipt_no, :string do
      constraints max_length: 10
    end

    attribute :line_item_key, :string do
      constraints max_length: 10
    end

    attribute :tax_code, :string do
      constraints max_length: 10
    end

    attribute :line_item_description, :string do
      constraints max_length: 20
    end

    # Date fields
    attribute :transaction_date, :date, allow_nil? false
    attribute :amortization_start_date, :date
    attribute :amortization_end_date, :date

    # Boolean fields
    attribute :amortize, :boolean, default: false
    attribute :last_day, :boolean, default: false

    # Numeric fields
    attribute :tax_version, :integer, default: 0
    attribute :distribution_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_distribution_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1
    attribute :total_multicurrency_variance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :amortization_cycles, :decimal, constraints: [precision: 4, scale: 0], default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :invoice, AccountMate.AP.Invoice do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end

    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end
end

# Check Resource (Apchck table)
defmodule AccountMate.AP.Check do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apchck"
    repo AccountMate.Repo
  end

  attributes do
    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :check_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :pay_to, :string do
      constraints max_length: 40
      allow_nil? false
    end

    attribute :check_type, :string do
      constraints max_length: 1
      description "C - Computer Check, H - Handwritten Check, N - Non-Check Payment"
      allow_nil? false
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :original_check_no, :string do
      constraints max_length: 10
    end

    # Date fields
    attribute :check_date, :date
    attribute :create_date, :date, allow_nil? false

    # Boolean fields
    attribute :on_hold, :boolean, default: false
    attribute :reissued_check, :boolean, default: false

    # Numeric fields
    attribute :check_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_check_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1, allow_nil? false
    attribute :bank_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :applied_payments, AccountMate.AP.AppliedPayment do
      source_attribute [:bank_no, :check_no]
      destination_attribute [:bank_no, :check_no]
    end
  end

  identities do
    identity :unique_bank_check, [:bank_no, :check_no]
  end
end

# Applied Payment Resource (Apcapp table)
defmodule AccountMate.AP.AppliedPayment do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apcapp"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :invoice_no, :string do
      constraints max_length: 20
      allow_nil? false
    end

    attribute :invoice_type, :string do
      constraints max_length: 1
    end

    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :check_no, :string do
      constraints max_length: 10
    end

    attribute :credit_card_vendor_no, :string do
      constraints max_length: 10
    end

    attribute :charge_transaction_no, :string do
      constraints max_length: 20
    end

    attribute :bank_name, :string do
      constraints max_length: 35
    end

    attribute :bank_account, :string do
      constraints max_length: 20
    end

    attribute :bank_route, :string do
      constraints max_length: 9
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :paid_date, :date, allow_nil? false

    # Numeric fields - Home Currency
    attribute :check_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :electronic_payment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :total_tax_claim_back_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :used_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0

    # Foreign Currency amounts
    attribute :foreign_check_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_tax_claim_back_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_withholding_tax_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_used_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0

    attribute :invoice_exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    belongs_to :invoice, AccountMate.AP.Invoice do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end

    belongs_to :check, AccountMate.AP.Check do
      source_attribute [:bank_no, :check_no]
      destination_attribute [:bank_no, :check_no]
    end
  end
end

# Vendor Address Resource (Apvadr table)
defmodule AccountMate.AP.VendorAddress do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apvadr"
    repo AccountMate.Repo
  end

  attributes do
    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :type, :string do
      constraints max_length: 1
      description "F - Factor (Pay To) Address, O - Order Address"
      allow_nil? false
      primary_key? true
    end

    attribute :address_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :company, :string do
      constraints max_length: 40
    end

    attribute :addr1, :string do
      constraints max_length: 40
      description "Address 1"
    end

    attribute :addr2, :string do
      constraints max_length: 40
      description "Address 2"
    end

    attribute :city, :string do
      constraints max_length: 20
    end

    attribute :state, :string do
      constraints max_length: 15
    end

    attribute :zip, :string do
      constraints max_length: 10
    end

    attribute :country, :string do
      constraints max_length: 25
    end

    attribute :phone, :string do
      constraints max_length: 20
    end

    attribute :contact, :string do
      constraints max_length: 30
    end

    attribute :email, :string do
      description "E-mail Address"
      allow_nil? false
    end

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end

  identities do
    identity :unique_vendor_type_address, [:vendor_no, :type, :address_no]
  end
end

# Vendor Contact Resource (Apcont table)
defmodule AccountMate.AP.VendorContact do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apcont"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :first_name, :string do
      constraints max_length: 15
    end

    attribute :last_name, :string do
      constraints max_length: 15
    end

    attribute :title, :string do
      constraints max_length: 30
    end

    attribute :phone, :string do
      constraints max_length: 20
    end

    attribute :fax, :string do
      constraints max_length: 20
    end

    attribute :email, :string
    
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end
end

# Vendor Activity Resource (Apvact table)
defmodule AccountMate.AP.VendorActivity do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "apvact"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :activity_type, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :transaction_type, :string do
      constraints max_length: 4
      allow_nil? false
      description "NONE - None, INVC - AR Invoice, SORD - Sales Order/Quote, RMAT - RMA"
    end

    attribute :transaction_no, :string do
      constraints max_length: 20
    end

    attribute :description, :string do
      constraints max_length: 35
      allow_nil? false
    end

    attribute :entered_by, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :contact, :string do
      constraints max_length: 15
    end

    attribute :status, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :file_attachment, :string

    attribute :activity_date, :date, allow_nil? false

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end
end

# Recurring Invoice Resource (Aprcri table)
defmodule AccountMate.AP.RecurringInvoice do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "aprcri"
    repo AccountMate.Repo
  end

  attributes do
    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :invoice_no, :string do
      constraints max_length: 20
      allow_nil? false
      primary_key? true
    end

    attribute :po_no, :string do
      constraints max_length: 10
      description "PO #"
    end

    attribute :reference, :string do
      constraints max_length: 20
    end

    attribute :description, :string do
      constraints max_length: 35
    end

    attribute :paymseolean, default: false
    attribute :claim_gst, :boolean, default: false
    attribute :claim_pst, :boolean, default: false
    attribute :use_vendor_tax_settings, :boolean, default: false
    attribute :recalculate_tax, :boolean, default: false

    # Numeric fields
    attribute :cycles, :integer, default: 0
    attribute :non_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :invoice_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :discount_days, :integer, default: 0
    attribute :due_days, :integer, default: 0
    attribute :tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_version, :integer, default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :distributions, AccountMate.AP.RecurringInvoiceDistribution do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end
  end

  identities do
    identity :unique_vendor_recurring_invoice, [:vendor_no, :invoice_no]
  end
end

# Recurring Invoice Distribution Resource (Aprcrd table)
defmodule AccountMate.AP.RecurringInvoiceDistribution do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "aprcrd"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :vendor_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :invoice_no, :string do
      constraints max_length: 20
      allow_nil? false
    end

    attribute :gl_distribution_account, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :type, :string do
      constraints max_length: 2
    end

    attribute :tax_code, :string do
      constraints max_length: 10
    end

    attribute :tax_claim_code, :string do
      constraints max_length: 1
      description "G - GST Tax Claim Code, P - PST Tax Claim Code"
    end

    # Numeric fields
    attribute :tax_version, :integer, default: 0
    attribute :distribution_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :recurring_invoice, AccountMate.AP.RecurringInvoice do
      source_attribute [:vendor_no, :invoice_no]
      destination_attribute [:vendor_no, :invoice_no]
    end

    belongs_to :vendor, AccountMate.AP.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end
  end
   type_1099, :string do
      constraints max_length: 1
      description "1099 Payment Type"
    end

    attribute :payment_urgency, :string do
      constraints max_length: 1
      default "1"
      allow_nil? false
    end

    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :recurring_cycle, :string do
      constraints max_length: 1
      default "M"
      allow_nil? false
      description "W - Weekly, M - Monthly, B - Bimonthly, Q - Quarterly, S - Semi-Annually, A - Annually"
    end

    attribute :payable_account, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :sales_tax_code, :string do
      constraints max_length: 10
    end

    attribute :entered_by, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :status, :string do
      constraints max_length: 1
      allow_nil? false
    end

    # Date fields
    attribute :last_recurring_date, :date
    attribute :next_recurring_date, :date, allow_nil? false
    attribute :end_recurring_date, :date

    # Boolean fields
    attribute :last_day_of_month, :bo
