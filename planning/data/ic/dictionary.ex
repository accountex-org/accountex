# Inventory Item Resource
defmodule AccountMateIC.Inventory.Item do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "icitem"
    repo AccountMateIC.Repo
  end

  attributes do
    # Primary key
    attribute :item_no, :string do
      description "Item #"
      primary_key? true
      allow_nil? false
      constraints max_length: 20
    end

    # Basic item information
    attribute :description, :string do
      description "Description"
      allow_nil? false
      constraints max_length: 54
    end

    attribute :foreign_description, :string do
      description "Foreign Description"
      constraints max_length: 54
    end

    attribute :inventory_type, :string do
      description "Inventory Type"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :specification_type1, :string do
      description "Specification Type 1"
      constraints max_length: 10
    end

    attribute :specification_type2, :string do
      description "Specification Type 2"
      constraints max_length: 10
    end

    # Barcodes
    attribute :barcode1, :string do
      description "Barcode 1"
      constraints max_length: 20
    end

    attribute :barcode2, :string do
      description "Barcode 2"
      constraints max_length: 20
    end

    # Status
    attribute :status, :string do
      description "Status - A=Active, I=Inactive"
      default "A"
      constraints one_of: ["A", "I"]
    end

    # Units of measure
    attribute :stock_uom, :string do
      description "Stock U of M"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :sales_uom, :string do
      description "Sales U of M"
      constraints max_length: 10
    end

    attribute :purchase_uom, :string do
      description "Purchase U of M"
      constraints max_length: 10
    end

    # Categories
    attribute :item_class, :string do
      description "Class"
      constraints max_length: 10
    end

    attribute :product_line, :string do
      description "Product Line"
      constraints max_length: 10
    end

    attribute :commission_code, :string do
      description "Commission"
      constraints max_length: 10
    end

    attribute :vendor_no, :string do
      description "Vendor #"
      constraints max_length: 10
    end

    # Pricing
    attribute :minimum_price_type, :string do
      description "Minimum Price Type"
      default "PC"
      constraints max_length: 2
    end

    attribute :buyer, :string do
      description "Buyer"
      constraints max_length: 10
    end

    attribute :tax_code, :string do
      description "Sales Tax Code"
      constraints max_length: 10
    end

    # Amortization
    attribute :amortization_method, :string do
      description "Amortization Method - L=Straight-line, S=Specific"
      constraints one_of: ["L", "S"]
    end

    attribute :amortization_recurring, :string do
      description "Amortization Recurring Cycle - W=Weekly, B=Bimonthly, Q=Quarterly, S=Semi-Annually, A=Annually"
      constraints one_of: ["W", "B", "Q", "S", "A"]
    end

    # GL Accounts
    attribute :contract_costs_account, :string do
      description "Contract Costs Account"
      constraints max_length: 30
    end

    attribute :contract_obligations_account, :string do
      description "Contract Obligations Account"
      constraints max_length: 30
    end

    attribute :contract_discounts_account, :string do
      description "Contract Discounts Account"
      constraints max_length: 30
    end

    attribute :tax_category_code, :string do
      description "Tax Category Code"
      constraints max_length: 15
    end

    # Dates
    attribute :create_date, :utc_datetime do
      description "Create Date"
      allow_nil? false
    end

    attribute :last_sale_date, :utc_datetime do
      description "Last Sale Date"
    end

    attribute :last_finish_date, :utc_datetime do
      description "Last Finish Date"
    end

    attribute :special_price_start, :utc_datetime do
      description "Start Date - Start of the effectivity of the special price"
    end

    attribute :special_price_end, :utc_datetime do
      description "End Date - End of the effectivity of the special price"
    end

    attribute :modified_time, :utc_datetime do
      description "Modify Time"
      allow_nil? false
    end

    # Boolean flags
    attribute :use_specification?, :boolean do
      description "Use Specification"
      default false
    end

    attribute :ar_item?, :boolean do
      description "Use in AR"
      default false
    end

    attribute :po_item?, :boolean do
      description "Use in PO"
      default false
    end

    attribute :mi_item?, :boolean do
      description "Use in MI"
      default false
    end

    attribute :io_item?, :boolean do
      description "Use in IO"
      default false
    end

    attribute :kit_item?, :boolean do
      description "Kit Item"
      default false
    end

    attribute :use_kit_no?, :boolean do
      description "Use Kit #"
      default false
    end

    attribute :lot_controlled?, :boolean do
      description "Lot-controlled Item"
      default false
    end

    attribute :substitute_items_defined?, :boolean do
      description "Substitute Items Defined"
      default false
    end

    attribute :parent_item?, :boolean do
      description "Parent Item"
      default false
    end

    attribute :multi_level_price?, :boolean do
      description "Multi-Level Price"
      default false
    end

    attribute :check_onhand?, :boolean do
      description "Check On-hand"
      default false
    end

    attribute :update_onhand?, :boolean do
      description "Update On-hand"
      default false
    end

    attribute :taxable1?, :boolean do
      description "Taxable"
      default false
    end

    attribute :taxable2?, :boolean do
      description "Taxable"
      default false
    end

    attribute :allow_negative_onhand_updates?, :boolean do
      description "Allow Negative On-hand Updates"
      default false
    end

    attribute :allow_negative_entries_on_invoice?, :boolean do
      description "Allow Negative Entries on Invoice"
      default false
    end

    attribute :allow_negative_price?, :boolean do
      description "Allow Negative Price"
      default false
    end

    attribute :overwrite_description?, :boolean do
      description "Overwrite"
      default false
    end

    attribute :allow_overwrite_price?, :boolean do
      description "Allow Overwrite Price"
      default false
    end

    attribute :allow_overwrite_discount?, :boolean do
      description "Allow Overwrite Discount"
      default false
    end

    attribute :allow_overwrite_tax_status?, :boolean do
      description "Allow Overwrite Tax Status"
      default false
    end

    attribute :overwrite_weight?, :boolean do
      description "Overwrite Weight"
      default false
    end

    attribute :overwrite_revenue_code?, :boolean do
      description "Overwrite Revenue Code"
      default false
    end

    attribute :overwrite_kit_components?, :boolean do
      description "Overwrite Kit Components"
      default false
    end

    attribute :print_serial_no?, :boolean do
      description "Print Serial #"
      default false
    end

    attribute :print_lot_no?, :boolean do
      description "Print Lot #"
      default false
    end

    attribute :overwrite_remark_on_invoice?, :boolean do
      description "Overwrite Remark on Invoice"
      default false
    end

    attribute :print_remark_on_invoice?, :boolean do
      description "Print Remark on Invoice"
      default false
    end

    attribute :print_remark_on_ar_packing_slip?, :boolean do
      description "Print Remark on AR Packing Slip"
      default false
    end

    attribute :overwrite_remark_on_sales_order?, :boolean do
      description "Overwrite Remark on Sales Order"
      default false
    end

    attribute :print_remark_on_sales_order?, :boolean do
      description "Print Remark on Sales Order"
      default false
    end

    attribute :print_remark_on_so_pick_list?, :boolean do
      description "Print Remark on SO Pick List"
      default false
    end

    attribute :print_remark_on_so_packing_slip?, :boolean do
      description "Print Remark on SO Packing Slip"
      default false
    end

    attribute :overwrite_remark_on_purchase_order?, :boolean do
      description "Overwrite Remark on Purchase Order"
      default false
    end

    attribute :print_remark_on_purchase_order?, :boolean do
      description "Print Remark on Purchase Order"
      default false
    end

    attribute :overwrite_remark_in_mi?, :boolean do
      description "Overwrite Remark in MI"
      default false
    end

    attribute :print_remark_in_mi?, :boolean do
      description "Print Remark in MI"
      default false
    end

    attribute :allow_overwrite_ra_remark?, :boolean do
      description "Allow Overwrite RA Remark"
      default false
    end

    attribute :allow_print_ra_remark?, :boolean do
      description "Allow Print RA Remark"
      default false
    end

    attribute :print_remark_on_ra_packing_slip?, :boolean do
      description "Print Remark on RA Packing Slip"
      default false
    end

    attribute :overwrite_commission?, :boolean do
      description "Overwrite Commission"
      default false
    end

    attribute :allow_discarding?, :boolean do
      description "Allow Discarding"
      default false
    end

    attribute :allow_repairing?, :boolean do
      description "Allow Repairing"
      default false
    end

    attribute :lifetime?, :boolean do
      description "Life Time"
      default false
    end

    attribute :required_prebuild?, :boolean do
      description "Required Prebuild"
      default false
    end

    attribute :upsell_item?, :boolean do
      description "Upsell Item"
      default false
    end

    attribute :upsell_subs_by_specification?, :boolean do
      description "Upsell / subs by specification"
      default false
    end

    attribute :amortize?, :boolean do
      description "Amortize"
      default false
    end

    attribute :use_standard_cost?, :boolean do
      description "Use Standard Cost"
      default false
    end

    attribute :calculate_price_from_component?, :boolean do
      description "Calculate Price Form Component"
      default false
    end

    # Numeric fields
    attribute :cost_type, :integer do
      description "Cost Type - 1=Average, 2=FIFO, 3=LIFO, 4=Specific ID, 5=Average with S/N, 6=Standard, 7=Standard w/ Spec ID, 8=Standard w/ S/N"
      default 1
      constraints min: 1, max: 8
    end

    attribute :minimum_price, :decimal do
      description "Minimum Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :qty_decimals, :integer do
      description "Qty Decimals"
      default 0
      constraints min: 0, max: 4
    end

    attribute :discount_rate, :decimal do
      description "Discount Rate - Maximum Discount Rate set for the item"
      default 0
      constraints precision: 6, scale: 2
    end

    attribute :weight, :decimal do
      description "Weight"
      default 0
      constraints precision: 16, scale: 2
    end

    attribute :standard_cost, :decimal do
      description "Standard Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :return_cost, :decimal do
      description "Return Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :last_finish_cost, :decimal do
      description "Last Finish Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :unit_price, :decimal do
      description "Unit Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :unit_price_incl_tax, :decimal do
      description "Unit Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :special_price, :decimal do
      description "Special Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :special_price_incl_tax, :decimal do
      description "Special Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :last_sale_price, :decimal do
      description "Last Sale Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :last_sale_price_incl_tax, :decimal do
      description "Last Sales Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :restock_percent, :decimal do
      description "Restock Percent"
      default 0
      constraints precision: 6, scale: 2
    end

    attribute :restock_min_amount, :decimal do
      description "Restock Min Amount"
      default 0
      constraints precision: 18, scale: 4
    end

    attribute :restock_min_amount_incl_tax, :decimal do
      description "Restock Min Amount + Tax"
      default 0
      constraints precision: 18, scale: 4
    end

    attribute :repair_price, :decimal do
      description "Repair Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :repair_price_incl_tax, :decimal do
      description "Repair Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :amortization_cycles, :integer do
      description "No. of Cycles"
      default 0
    end

    # Configuration codes
    attribute :configuration_code, :string do
      description "Configuration Code"
      constraints max_length: 10
    end

    attribute :definition_code, :string do
      description "Defination Code"
      constraints max_length: 20
    end

    attribute :base_def_item_no, :string do
      description "Base Def Item #"
      constraints max_length: 20
    end

    attribute :alt_bom_item_no, :string do
      description "Alt BOM Item #"
      constraints max_length: 20
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :inventory_type, AccountMateIC.Inventory.Type do
      source_attribute :inventory_type
      destination_attribute :type_code
    end

    belongs_to :vendor, AccountMateIC.Vendor do
      source_attribute :vendor_no
      destination_attribute :vendor_no
    end

    has_many :warehouse_items, AccountMateIC.Inventory.WarehouseItem do
      source_attribute :item_no
      destination_attribute :item_no
    end

    has_many :adjustments, AccountMateIC.Inventory.Adjustment do
      source_attribute :item_no
      destination_attribute :item_no
    end

    has_many :kit_formulas, AccountMateIC.Inventory.KitFormula do
      source_attribute :item_no
      destination_attribute :kit_item_no
    end

    has_many :lot_controls, AccountMateIC.Inventory.LotControl do
      source_attribute :item_no
      destination_attribute :item_no
    end

    has_many :transfers, AccountMateIC.Inventory.Transfer do
      source_attribute :item_no
      destination_attribute :item_no1
    end

    has_one :notepad, AccountMateIC.Inventory.ItemNotepad do
      source_attribute :item_no
      destination_attribute :item_no
    end

    has_one :remark, AccountMateIC.Inventory.ItemRemark do
      source_attribute :item_no
      destination_attribute :item_no
    end
  end
end

# Inventory Warehouse Resource
defmodule AccountMateIC.Inventory.WarehouseItem do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "iciwhs"
    repo AccountMateIC.Repo
  end

  attributes do
    # Composite primary key through unique_id
    attribute :unique_id, :string do
      description "Unique ID"
      primary_key? true
      allow_nil? false
      constraints max_length: 15
    end

    attribute :item_no, :string do
      description "Item #"
      allow_nil? false
      constraints max_length: 20
    end

    attribute :specification_code1, :string do
      description "Specification Code 1"
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      description "Specification Code 2"
      constraints max_length: 10
    end

    attribute :warehouse, :string do
      description "Warehouse"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :serial_number, :string do
      description "Serial # - Applicable for serialized items only"
      constraints max_length: 30
    end

    # GL Accounts
    attribute :inventory_account, :string do
      description "Inventory Account"
      allow_nil? false
      constraints max_length: 30
    end

    attribute :in_transit_inventory_account, :string do
      description "In-transit Inventory Account"
      constraints max_length: 30
    end

    attribute :uninvoiced_inventory_account, :string do
      description "Un-invoiced Inventory Account"
      constraints max_length: 30
    end

    attribute :revenue_code, :string do
      description "Revenue Code"
      constraints max_length: 10
    end

    attribute :contract_costs_account, :string do
      description "Contract Costs Account"
      constraints max_length: 30
    end

    attribute :contract_obligations_account, :string do
      description "Contract Obligations Account"
      constraints max_length: 30
    end

    attribute :contract_discounts_account, :string do
      description "Contract Discounts Account"
      constraints max_length: 30
    end

    # Dates
    attribute :last_receive_date, :utc_datetime do
      description "Last Receive Date"
    end

    attribute :last_repair_date, :utc_datetime do
      description "Last Repair Date"
    end

    # Numeric fields
    attribute :manufacturing_lead_time, :integer do
      description "Manufacturing Lead Time"
      default 0
    end

    attribute :safety_stock, :decimal do
      description "Safety Stock"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :reorder_point, :decimal do
      description "Reorder Points"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :reorder_qty, :decimal do
      description "Reorder Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :onhand_qty, :decimal do
      description "On-hand Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :onorder_qty, :decimal do
      description "On-order Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :inprocess_qty, :decimal do
      description "In-process Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :allocated_qty, :decimal do
      description "Allocated Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :booked_qty, :decimal do
      description "Booked Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :intransit_qty, :decimal do
      description "In-transit Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :cost, :decimal do
      description "Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :last_receive_cost, :decimal do
      description "Last Receive Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :total_cost, :decimal do
      description "Total Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :last_repair_cost, :decimal do
      description "Last Repair Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :rma_onhand, :decimal do
      description "RMA On-hand"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :rma_cost, :decimal do
      description "RMA Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :repair_cost, :decimal do
      description "Repair Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :interim_qty, :decimal do
      description "Interim Qty"
      default 0
      constraints precision: 16, scale: 4
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :item, AccountMateIC.Inventory.Item do
      source_attribute :item_no
      destination_attribute :item_no
    end

    belongs_to :warehouse_master, AccountMateIC.Warehouse do
      source_attribute :warehouse
      destination_attribute :warehouse_code
    end

    has_many :bins, AccountMateIC.Inventory.Bin do
      source_attribute :item_no
      destination_attribute :item_no
      filter expr(warehouse == parent(warehouse))
    end
  end
end

# Inventory Adjustment Resource
defmodule AccountMateIC.Inventory.Adjustment do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "iciadj"
    repo AccountMateIC.Repo
  end

  attributes do
    attribute :unique_id, :string do
      description "Unique ID"
      primary_key? true
      allow_nil? false
      constraints max_length: 15
    end

    attribute :adjustment_no, :string do
      description "Adjust #"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :module, :string do
      description "Module"
      allow_nil? false
      constraints max_length: 2
    end

    attribute :item_no, :string do
      description "Item #"
      allow_nil? false
      constraints max_length: 20
    end

    attribute :specification_code1, :string do
      description "Specification Code 1"
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      description "Specification Code 2"
      constraints max_length: 10
    end

    attribute :warehouse, :string do
      description "Warehouse"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :bin, :string do
      description "Bin"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :entered_by, :string do
      description "Entered By"
      allow_nil? false
      constraints max_length: 30
    end

    attribute :adjustment_account, :string do
      description "Adjust Account"
      allow_nil? false
      constraints max_length: 30
    end

    attribute :remark, :string do
      description "Remark"
      constraints max_length: 35
    end

    attribute :posted_to_gl, :string do
      description "Posted to GL"
      constraints max_length: 1
    end

    attribute :transaction_type, :string do
      description "Trs Type"
      default "IADJ"
      constraints max_length: 4
    end

    attribute :adjustment_date, :utc_datetime do
      description "Adjust Date"
      allow_nil? false
    end

    attribute :qty_decimals, :integer do
      description "Qty Decimals"
      allow_nil? false
      default 0
    end

    attribute :adjustment_qty, :decimal do
      description "Adjust Qty"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :cost, :decimal do
      description "Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :total_cost, :decimal do
      description "Total Cost"
      default 0
      constraints precision: 16, scale: 4
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :item, AccountMateIC.Inventory.Item do
      source_attribute :item_no
      destination_attribute :item_no
    end
  end
end

# Inventory Type Resource
defmodule AccountMateIC.Inventory.Type do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "ictype"
    repo AccountMateIC.Repo
  end

  attributes do
    attribute :type_code, :string do
      description "Inventory Type"
      primary_key? true
      allow_nil? false
      constraints max_length: 10
    end

    attribute :type_description, :string do
      description "Type Description"
      allow_nil? false
      constraints max_length: 40
    end

    attribute :item_description, :string do
      description "Item Description"
      constraints max_length: 54
    end

    attribute :foreign_item_description, :string do
      description "Foreign Item Description"
      constraints max_length: 54
    end

    attribute :stock_uom, :string do
      description "Stock U of M"
      constraints max_length: 10
    end

    attribute :sales_uom, :string do
      description "Sales U of M"
      constraints max_length: 10
    end

    attribute :purchase_uom, :string do
      description "Purchase U of M"
      constraints max_length: 10
    end

    attribute :item_class, :string do
      description "Class"
      constraints max_length: 10
    end

    attribute :product_line, :string do
      description "Product Line"
      constraints max_length: 10
    end

    attribute :commission_code, :string do
      description "Commission"
      constraints max_length: 10
    end

    attribute :revenue_code, :string do
      description "Revenue Code"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :inventory_account, :string do
      description "Inventory Account"
      allow_nil? false
      constraints max_length: 30
    end

    attribute :in_transit_inventory_account, :string do
      description "In-transit Inventory Account"
      allow_nil? false
      constraints max_length: 30
    end

    attribute :status, :string do
      description "Status - A=Active, I=Inactive"
      default "A"
      constraints one_of: ["A", "I"]
    end

    attribute :tax_code, :string do
      description "Sales Tax Code"
      allow_nil? false
      constraints max_length: 10
    end

    attribute :amortization_method, :string do
      description "Amortization Method - L=Straight-line, S=Specific"
      constraints one_of: ["L", "S"]
    end

    attribute :amortization_recurring, :string do
      description "Amortization Recurring Cycle"
      constraints one_of: ["W", "M", "B", "Q", "S", "A"]
    end

    attribute :contract_costs_account, :string do
      description "Contract Costs Account"
      constraints max_length: 30
    end

    attribute :contract_obligations_account, :string do
      description "Contract Obligations Account"
      constraints max_length: 30
    end

    attribute :contract_discounts_account, :string do
      description "Contract Discounts Account"
      constraints max_length: 30
    end

    attribute :interim_inventory_account, :string do
      description "Interim Inventory Account"
      constraints max_length: 30
    end

    attribute :tax_category_code, :string do
      description "Tax Category Code"
      constraints max_length: 15
    end

    # Boolean flags - simplified to main ones
    attribute :ar_item?, :boolean do
      description "Use in AR"
      default false
    end

    attribute :po_item?, :boolean do
      description "Use in PO"
      default false
    end

    attribute :mi_item?, :boolean do
      description "Use in MI"
      default false
    end

    attribute :io_item?, :boolean do
      description "Use in IO"
      default false
    end

    attribute :kit_item?, :boolean do
      description "Kit Item"
      default false
    end

    attribute :use_kit_no?, :boolean do
      description "Use Kit #"
      default false
    end

    attribute :lot_controlled?, :boolean do
      description "Lot-controlled Item"
      default false
    end

    attribute :use_specification?, :boolean do
      description "Use Specification"
      default false
    end

    attribute :check_onhand?, :boolean do
      description "Check On-hand"
      default false
    end

    attribute :update_onhand?, :boolean do
      description "Update On-hand"
      default false
    end

    attribute :taxable1?, :boolean do
      description "Taxable"
      default false
    end

    attribute :taxable2?, :boolean do
      description "Taxable"
      default false
    end

    attribute :required_prebuild?, :boolean do
      description "Required Prebuild"
      default false
    end

    attribute :amortize?, :boolean do
      description "Amortize"
      default false
    end

    attribute :use_standard_cost?, :boolean do
      description "Use Standard Cost"
      default false
    end

    # Numeric fields
    attribute :cost_type, :integer do
      description "Cost Type"
      default 1
      constraints min: 1, max: 8
    end

    attribute :qty_decimals, :integer do
      description "Qty Decimals"
      default 0
      constraints min: 0, max: 4
    end

    attribute :discount_rate, :decimal do
      description "Discount Rate"
      default 0
      constraints precision: 6, scale: 2
    end

    attribute :weight, :decimal do
      description "Weight"
      default 0
      constraints precision: 16, scale: 2
    end

    attribute :standard_cost, :decimal do
      description "Standard Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :return_cost, :decimal do
      description "Return Cost"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :price, :decimal do
      description "Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :price_incl_tax, :decimal do
      description "Unit Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :restock_percent, :decimal do
      description "Restock Percent"
      default 0
      constraints precision: 6, scale: 2
    end

    attribute :restock_min_amount, :decimal do
      description "Restock Min Amount"
      default 0
      constraints precision: 18, scale: 4
    end

    attribute :restock_min_amount_incl_tax, :decimal do
      description "Restock Min Amount + Tax"
      default 0
      constraints precision: 18, scale: 4
    end

    attribute :repair_price, :decimal do
      description "Repair Price"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :repair_price_incl_tax, :decimal do
      description "Repair Price + Tax"
      default 0
      constraints precision: 16, scale: 4
    end

    attribute :amortization_cycles, :integer do
      description "No. of Cycles"
      default 0
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    has_many :items, AccountMateIC.Inventory.Item do
      source_attribute :type_code
      destination_attribute :inventory_type
    end

    has_many :warehouse_types, AccountMateIC.Inventory.TypeWarehouse do
      source_attribute :type_code
      destination_attribute :type_code
    end
  end
end

# Warehouse Resource
defmodule AccountMateIC.Warehouse do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "icwhse"
    repo AccountMateIC.Repo
  end

  attributes do
    attribute :warehouse_code, :string do
      description "Warehouse #"
      primary_key? true
      allow_nil? false
      constraints max_length: 10
    end

    attribute :description, :string do
      description "Description"
      allow_nil? false
      constraints max_length: 35
    end

    attribute :address1, :string do
      description "Address 1"
      constraints max_length: 40
    end

    attribute :address2, :string do
      description "Address 2"
      constraints max_length: 40
    end

    attribute :city, :string do
      description "City"
      constraints max_length: 20
    end

    attribute :state, :string do
      description "State"
      constraints max_length: 15
    end

    attribute :zip, :string do
      description "Zip"
      constraints max_length: 10
    end

    attribute :country, :string do
      description "Country"
      constraints max_length: 20
    end

    attribute :phone, :string do
      description "Phone"
      constraints max_length: 17
    end

    attribute :contact, :string do
      description "Contact"
      constraints max_length: 30
    end

    attribute :tax_code, :string do
      description "Sales Tax Code"
      constraints max_length: 10
    end

    attribute :inventory_adjustment_account, :string do
      description "Inventory Adjusment Account"
      constraints max_length: 30
    end

    attribute :inventory_account, :string do
      description "Inventory Account"
      constraints max_length: 30
    end

    attribute :drop_ship?, :boolean do
      description "Drop Ship"
      default false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    has_many :warehouse_items, AccountMateIC.Inventory.WarehouseItem do
      source_attribute :warehouse_code
      destination_attribute :warehouse
    end

    has_many :bins, AccountMateIC.Inventory.WarehouseBin do
      source_attribute :warehouse_code
      destination_attribute :warehouse
    end
  end
end

# Warehouse Bin Resource
defmodule AccountMateIC.Inventory.WarehouseBin do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "icwbin"
    repo AccountMateIC.Repo

    custom_indexes do
      index [:warehouse, :bin], unique: true
    end
  end

  attributes do
    attribute :warehouse, :string do
      description "Warehouse"
      primary_key? true
      allow_nil? false
      constraints max_length: 10
    end

    attribute :bin, :string do
      description "Bin"
      primary_key? true
      allow_nil? false
      constraints max_length: 10
    end

    attribute :description, :string do
      description "Description"
      constraints max_length: 40
    end

    attribute :remark, :string do
      description "Remark"
      constraints max_length: 40
    end

    attribute :active?, :boolean do
      description "Active Bin"
      default true
    end

    attribute :receiving?, :boolean do
      description "Receiving Bin"
      default true
    end

    attribute :pick_sequence, :integer do
      description "Pick Sequence #"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :warehouse_master, AccountMateIC.Warehouse do
      source_attribute :warehouse
      destination_attribute :warehouse_code
    end
  end
end

# Unit of Measurement Resource  
defmodule AccountMateIC.UnitOfMeasurement do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "icunit"
    repo AccountMateIC.Repo
  end

  attributes do
    attribute :measure, :string do
      description "U of M"
      primary_key? true
      allow_nil? false
      constraints max_length: 10
    end

    attribute :description, :string do
      description "Description"
      allow_nil? false
      constraints max_length: 35
    end

    attribute :symbol, :string do
      description "Symbol"
      constraints max_length: 10
    end

    attribute :foreign_symbol, :string do
      description "Foreign Symbol"
      constraints max_length: 10
    end

    attribute :status, :string do
      description "Status - A=Active, I=Inactive"
      default "A"
      constraints one_of: ["A", "I"]
    end

    attribute :conversion_qty, :decimal do
      description "Conversion Factor"
      default 1
      constraints precision: 16, scale: 4
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
