# Bill of Materials Header Resource
defmodule AccountMate.Manufacturing.BillOfMaterialsHeader do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "mibomh"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Item #"
    end

    attribute :cspeccode1, :string do
      constraints max_length: 10
      description "Parent # Specification Code 1"
    end

    attribute :cspeccode2, :string do
      constraints max_length: 10
      description "Parent # Specification Code 2"
    end

    create_timestamp :dcreate, description: "Create Date"
    attribute :lcurrent, :boolean, default: false, description: "Current Version"
    attribute :nversion, :integer, description: "Version"
    update_timestamp :tmodified, description: "Last Modified"

    attribute :cremark, :string do
      constraints max_length: 35
      description "Remarks"
    end

    attribute :cstatus, :string do
      constraints max_length: 1
      description "Status"
    end
  end

  relationships do
    has_many :components, AccountMate.Manufacturing.BillOfMaterialsComponent do
      source_attribute :citemno
      destination_attribute :citemno
    end

    has_many :remnants, AccountMate.Manufacturing.BillOfMaterialsRemnant do
      source_attribute :citemno
      destination_attribute :citemno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Bill of Materials Components Resource
defmodule AccountMate.Manufacturing.BillOfMaterialsComponent do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miboml"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Item #"
    end

    attribute :cspeccode1, :string do
      constraints max_length: 10
      description "Parent # Specification Code 1"
    end

    attribute :cspeccode2, :string do
      constraints max_length: 10
      description "Parent # Specification Code 2"
    end

    attribute :ccompno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Component #"
    end

    attribute :ccspecode1, :string do
      constraints max_length: 10
      description "Component # Specification Code 1"
    end

    attribute :ccspecode2, :string do
      constraints max_length: 10
      description "Component # Specification Code 2"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Component Description"
    end

    attribute :cmeasure, :string do
      constraints max_length: 10
      description "Measure"
    end

    attribute :ctype, :string do
      constraints max_length: 1
      allow_nil? false
      default: "I"
      description "Component Type ('I' - Inventory, 'M'- Machine, 'L' - Labor)"
    end

    create_timestamp :dcreate, description: "Create Date"

    attribute :nqtydec, :integer, default: 0, description: "Decimal Places for Qty"
    attribute :nstep, :integer, description: "Step No"

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :nqty, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Quantity"
    end

    attribute :nrate, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Production Rate"
    end

    attribute :ncnvqty, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Conversion Factor"
    end
  end

  relationships do
    belongs_to :bill_of_materials_header, AccountMate.Manufacturing.BillOfMaterialsHeader do
      source_attribute :citemno
      destination_attribute :citemno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Work Order Resource
defmodule AccountMate.Manufacturing.WorkOrder do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miword"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "Work Order #"
    end

    attribute :crevision, :string do
      constraints max_length: 1
      default: ""
      description "Revision #"
    end

    attribute :cwarehouse, :string do
      constraints max_length: 10
      allow_nil? false
      description "Warehouse #"
    end

    attribute :csono, :string do
      constraints max_length: 10
      description "SO #"
    end

    attribute :ccustno, :string do
      constraints max_length: 10
      description "Customer #"
    end

    attribute :centerby, :string do
      constraints max_length: 30
      allow_nil? false
      description "Entered By"
    end

    attribute :dorder, :date, description: "Order Date"
    attribute :drequest, :date, description: "Request Date"
    create_timestamp :dcreate, description: "Create Date"

    attribute :lhold, :boolean, default: false, description: "Hold"
    attribute :lexploded, :boolean, default: false, description: "Exploded"
    attribute :lprtword, :boolean, description: "Work Order Printed"
    attribute :lmreqdate, :boolean, description: "Multiple Request Date"
  end

  relationships do
    has_many :line_items, AccountMate.Manufacturing.WorkOrderLineItem do
      source_attribute :cwono
      destination_attribute :cwono
    end

    has_many :remarks, AccountMate.Manufacturing.WorkOrderRemark do
      source_attribute :cwono
      destination_attribute :cwono
    end

    has_many :wip_records, AccountMate.Manufacturing.WorkInProcess do
      source_attribute :cwono
      destination_attribute :cwono
    end

    has_many :finished_jobs, AccountMate.Manufacturing.FinishedJob do
      source_attribute :cwono
      destination_attribute :cwono
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_work_order, [:cwono]
  end
end

# Work Order Line Items Resource
defmodule AccountMate.Manufacturing.WorkOrderLineItem do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miwtrs"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "Work Order #"
    end

    attribute :cjobno, :string do
      constraints max_length: 10
      description "Job #"
    end

    attribute :csono, :string do
      constraints max_length: 10
      description "SO #"
    end

    attribute :ccustno, :string do
      constraints max_length: 10
      description "Customer #"
    end

    attribute :cparentlvl, :string do
      constraints max_length: 3
      default: "0"
      description "Parent Level"
    end

    attribute :cparentnod, :string do
      constraints max_length: 5
      default: "0"
      description "Parent Node"
    end

    attribute :clevel, :string do
      constraints max_length: 3
      default: "1"
      description "Component Level"
    end

    attribute :cnode, :string do
      constraints max_length: 5
      default: "1"
      description "Component Node"
    end

    attribute :clineitem, :string do
      constraints max_length: 10
      description "Line Item Key"
    end

    attribute :cmparent, :string do
      constraints max_length: 20
      allow_nil? false
      description "Master Parent Item #"
    end

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Component #"
    end

    attribute :cspeccode1, :string do
      constraints max_length: 10
      description "Specification Code 1"
    end

    attribute :cspeccode2, :string do
      constraints max_length: 10
      description "Specification Code 2"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Component Description"
    end

    attribute :cclass, :string do
      constraints max_length: 10
      description "Component Class"
    end

    attribute :cshift, :string do
      constraints max_length: 10
      description "Component Shift"
    end

    attribute :ctype, :string do
      constraints max_length: 1
      allow_nil? false
      description "Component Type ('I' – Inventory, 'M' – Machine, 'L' – Labor)"
    end

    attribute :cbyjob, :string do
      constraints max_length: 1
      description "Processing Method"
    end

    attribute :dorder, :date, allow_nil? false, description: "Order Date"
    attribute :drequest, :date, allow_nil? false, description: "Request Date"
    attribute :dstart, :date, description: "Work-in-process Start Date"
    attribute :dfinish, :date, description: "Finish Date"
    attribute :dpost, :date, description: "Post Date"

    attribute :lcomplst, :boolean, default: true, description: "Parent Item"
    attribute :lcomplete, :boolean, default: false, description: "Completed"
    attribute :lprtrte, :boolean, default: false, description: "Routing Slip Printed"

    attribute :nqtydec, :integer, default: 0, description: "Decimal Places for Qty"
    attribute :nstep, :integer, default: 0, description: "Step"

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :nmfgqty, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Manufacturing Qty"
    end

    attribute :nfnhqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Finished Qty"
    end

    attribute :nwipqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Work-in-process Qty"
    end

    attribute :nrsvqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Used Qty"
    end

    attribute :nstkqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Qty Released"
    end

    attribute :ncnvqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Conversion Qty"
    end

    attribute :nbook, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Qty Allocated"
    end

    attribute :nstdcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Standard Cost"
    end

    attribute :nactfcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Actual Parent Finish Cost"
    end

    attribute :nactrcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Actual Component Finish Cost"
    end

    attribute :nactwcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Actual Parent Work-in-process Cost"
    end

    attribute :nactbcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Actual Component Work-in-process Cost"
    end

    attribute :nseq, :integer, default: 10, description: "Sequence"

    attribute :nscrapqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Scrap Quantity"
    end
  end

  relationships do
    belongs_to :work_order, AccountMate.Manufacturing.WorkOrder do
      source_attribute :cwono
      destination_attribute :cwono
    end

    has_many :instructions, AccountMate.Manufacturing.WorkOrderInstruction do
      source_attribute :cuid
      destination_attribute :cuid
    end

    has_many :remarks, AccountMate.Manufacturing.WorkOrderRemark do
      source_attribute :cuid
      destination_attribute :cuid
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Work In Process Resource
defmodule AccountMate.Manufacturing.WorkInProcess do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miwips"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :cwipno, :string do
      constraints max_length: 15
      description "WIP #"
    end

    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "Work Order #"
    end

    attribute :cjobno, :string do
      constraints max_length: 10
      allow_nil? false
      description "Job #"
    end

    attribute :csono, :string do
      constraints max_length: 10
      description "SO #"
    end

    attribute :ccustno, :string do
      constraints max_length: 10
      description "Customer #"
    end

    attribute :cparentlvl, :string do
      constraints max_length: 3
      allow_nil? false
      description "Parent Level"
    end

    attribute :cparentnod, :string do
      constraints max_length: 5
      description "Parent Node"
    end

    attribute :clevel, :string do
      constraints max_length: 3
      allow_nil? false
      description "Component Level"
    end

    attribute :cnode, :string do
      constraints max_length: 5
      description "Component Node"
    end

    attribute :clineitem, :string do
      constraints max_length: 10
      description "Line Item Key"
    end

    attribute :cmparent, :string do
      constraints max_length: 20
      allow_nil? false
      description "Master Parent Item"
    end

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Component #"
    end

    attribute :cspeccode1, :string do
      constraints max_length: 10
      description "Specification Code 1"
    end

    attribute :cspeccode2, :string do
      constraints max_length: 10
      description "Specification Code 2"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Component Description"
    end

    attribute :csernum, :string do
      constraints max_length: 30
      description "Serial #"
    end

    attribute :clotno, :string do
      constraints max_length: 15
      description "Lot #"
    end

    attribute :cshift, :string do
      constraints max_length: 10
      description "Component Shift"
    end

    attribute :ctype, :string do
      constraints max_length: 1
      allow_nil? false
      description "Component Type"
    end

    attribute :ctogl, :string do
      constraints max_length: 1
      default: ""
      description "Posted to GL"
    end

    attribute :cbin, :string do
      constraints max_length: 10
      allow_nil? false
      description "Bin #"
    end

    attribute :dorder, :date, allow_nil? false, description: "Order Date"
    attribute :drequest, :date, allow_nil? false, description: "Request Date"
    attribute :dstart, :date, allow_nil? false, description: "WIP Start Date"
    attribute :ditem, :date, description: "Item Date"
    attribute :dpost, :date, allow_nil? false, description: "Post Date"

    attribute :lvoid, :boolean, default: false, description: "Void"
    attribute :lcomplst, :boolean, default: true, description: "Parent Item"
    attribute :lprtrte, :boolean, default: false, description: "Routing Slip Printed"

    attribute :nqtydec, :integer, default: 0, description: "Decimal Places for Qty"
    attribute :nstep, :integer, default: 0, description: "Step"

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :nwipqty, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Work-in-process Qty"
    end

    attribute :nrsvqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Used Qty"
    end

    attribute :nbook, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Qty Allocated"
    end

    attribute :ncost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Unit Cost"
    end

    attribute :nupcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Cost"
    end

    attribute :ndncost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Cost"
    end

    attribute :nprodcost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Extended Cost"
    end

    attribute :namount, :decimal do
      constraints precision: 18, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Production Cost"
    end
  end

  relationships do
    belongs_to :work_order, AccountMate.Manufacturing.WorkOrder do
      source_attribute :cwono
      destination_attribute :cwono
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Finished Job Resource
defmodule AccountMate.Manufacturing.FinishedJob do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "mifinh"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :cwipno, :string do
      constraints max_length: 15
      description "WIP #"
    end

    attribute :cfnhno, :string do
      constraints max_length: 15
      description "Finish #"
    end

    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "Work Order #"
    end

    attribute :cjobno, :string do
      constraints max_length: 10
      allow_nil? false
      description "Job #"
    end

    attribute :csono, :string do
      constraints max_length: 10
      description "SO #"
    end

    attribute :ccustno, :string do
      constraints max_length: 10
      description "Customer #"
    end

    attribute :cparentlvl, :string do
      constraints max_length: 3
      allow_nil? false
      description "Parent Level"
    end

    attribute :cparentnod, :string do
      constraints max_length: 5
      description "Parent Node"
    end

    attribute :clevel, :string do
      constraints max_length: 3
      description "Component Level"
    end

    attribute :cnode, :string do
      constraints max_length: 5
      description "Component Node"
    end

    attribute :clineitem, :string do
      constraints max_length: 10
      description "Line Item Key"
    end

    attribute :cmparent, :string do
      constraints max_length: 20
      allow_nil? false
      description "Master Parent Item #"
    end

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Component #"
    end

    attribute :cspeccode1, :string do
      constraints max_length: 10
      description "Specification Code 1"
    end

    attribute :cspeccode2, :string do
      constraints max_length: 10
      description "Specification Code 2"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Component Description"
    end

    attribute :csernum, :string do
      constraints max_length: 30
      allow_nil? false
      description "Serial #"
    end

    attribute :clotno, :string do
      constraints max_length: 15
      description "Lot #"
    end

    attribute :cshift, :string do
      constraints max_length: 10
      allow_nil? false
      description "Component Shift"
    end

    attribute :ctype, :string do
      constraints max_length: 1
      allow_nil? false
      description "Component Type"
    end

    attribute :ctogl, :string do
      constraints max_length: 1
      default: ""
      description "Posted to GL"
    end

    attribute :cbin, :string do
      constraints max_length: 10
      allow_nil? false
      description "Bin"
    end

    attribute :csourceno, :string do
      constraints max_length: 15
      default: ""
      description "Source #"
    end

    attribute :dorder, :date, allow_nil? false, description: "Order Date"
    attribute :drequest, :date, allow_nil? false, description: "Request Date"
    attribute :dstart, :date, allow_nil? false, description: "WIP Start Date"
    attribute :dfinish, :date, allow_nil? false, description: "Finish Date"
    attribute :ditem, :date, description: "Item Date"
    attribute :dpost, :date, allow_nil? false, description: "Post Date"

    attribute :lcomplst, :boolean, default: true, description: "Parent Item"
    attribute :lvoid, :boolean, default: false, description: "Void"
    attribute :lprtlbl, :boolean, default: false, description: "Finished Job Label Printed"

    attribute :nqtydec, :integer, default: 0, description: "Decimal Places for Qty"

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :nfnhqty, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Finished Qty"
    end

    attribute :nrsvqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Used Qty"
    end

    attribute :nstkqty, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Quantity Released"
    end

    attribute :ncost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Unit Cost"
    end

    attribute :nupcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Cost"
    end

    attribute :ndncost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Cost"
    end

    attribute :nprodcost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Production Cost"
    end

    attribute :ncostvar, :decimal do
      constraints precision: 18, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Cost Variance"
    end

    attribute :novhdcost, :decimal do
      constraints precision: 18, scale: 4
      default: Decimal.new("0")
      description "Overhead Cost"
    end

    attribute :namount, :decimal do
      constraints precision: 18, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Extended Cost"
    end

    attribute :nscrapamt, :decimal do
      constraints precision: 18, scale: 4
      description "Scrap Amount"
    end

    attribute :nscrapqty, :decimal do
      constraints precision: 18, scale: 4
      description "Scrap Quantity"
    end
  end

  relationships do
    belongs_to :work_order, AccountMate.Manufacturing.WorkOrder do
      source_attribute :cwono
      destination_attribute :cwono
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Labor Resource
defmodule AccountMate.Manufacturing.Labor do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "milabr"
    repo AccountMate.Repo
  end

  attributes do
    attribute :claborno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Labor #"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Description"
    end

    attribute :cidno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Identification #"
    end

    attribute :cclass, :string do
      constraints max_length: 10
      description "Class"
    end

    attribute :cshift, :string do
      constraints max_length: 10
      description "Work Shift"
    end

    attribute :cglacc, :string do
      constraints max_length: 30
      allow_nil? false
      description "GL Account ID"
    end

    attribute :cstatus, :string do
      constraints max_length: 1
      allow_nil? false
      default: "A"
      description "Status"
    end

    create_timestamp :dcreate, description: "Create Date"

    attribute :nrate, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Production Rate"
    end

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :ntimework, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Time Worked"
    end

    attribute :ntimebook, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Time Allocated"
    end

    attribute :nupcost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Setup Cost"
    end

    attribute :ndncost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Teardown Cost"
    end

    attribute :ncost, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Labor Cost"
    end
  end

  relationships do
    has_one :notepad, AccountMate.Manufacturing.LaborNotepad do
      source_attribute :claborno
      destination_attribute :claborno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_labor, [:claborno]
  end
end

# Machine Resource
defmodule AccountMate.Manufacturing.Machine do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "mimach"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cmachno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Machine #"
    end

    attribute :cdescript, :string do
      constraints max_length: 54
      allow_nil? false
      description "Description"
    end

    attribute :cidno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Identification #"
    end

    attribute :cclass, :string do
      constraints max_length: 10
      allow_nil? false
      description "Class"
    end

    attribute :cshift, :string do
      constraints max_length: 10
      allow_nil? false
      description "Work Shift"
    end

    attribute :cglacc, :string do
      constraints max_length: 30
      description "GL Account ID"
    end

    attribute :cstatus, :string do
      constraints max_length: 1
      allow_nil? false
      default: "A"
      description "Status"
    end

    create_timestamp :dcreate, description: "Create Date"

    attribute :lchkonhand, :boolean, default: false, description: "Check On-hand Qty"

    attribute :nrate, :decimal do
      constraints precision: 16, scale: 4
      default: Decimal.new("0")
      description "Production Rate"
    end

    attribute :nuptime, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Setup Time"
    end

    attribute :ndntime, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Teardown Time"
    end

    attribute :ntbotime, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Time Between Overhaul"
    end

    attribute :ntimeused, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Time Used"
    end

    attribute :ntimebook, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Time Allocated"
    end

    attribute :nupcost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Setup Cost"
    end

    attribute :ndncost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Teardown Cost"
    end

    attribute :ncost, :decimal do
      constraints precision: 16, scale: 4
      allow_nil? false
      default: Decimal.new("0")
      description "Machine Cost"
    end
  end

  relationships do
    has_one :notepad, AccountMate.Manufacturing.MachineNotepad do
      source_attribute :cmachno
      destination_attribute :cmachno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_machine, [:cmachno]
  end
end

# Labor Notepad Resource
defmodule AccountMate.Manufacturing.LaborNotepad do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "milnot"
    repo AccountMate.Repo
  end

  attributes do
    attribute :claborno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Labor#"
    end

    attribute :mnotepad, :string, description: "Notepad"
  end

  relationships do
    belongs_to :labor, AccountMate.Manufacturing.Labor do
      source_attribute :claborno
      destination_attribute :claborno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_labor_notepad, [:claborno]
  end
end

# Machine Notepad Resource
defmodule AccountMate.Manufacturing.MachineNotepad do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "mimnot"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cmachno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Machine #"
    end

    attribute :mnotepad, :string, description: "Notepad"
  end

  relationships do
    belongs_to :machine, AccountMate.Manufacturing.Machine do
      source_attribute :cmachno
      destination_attribute :cmachno
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_machine_notepad, [:cmachno]
  end
end

# Work Order Remark Resource
defmodule AccountMate.Manufacturing.WorkOrderRemark do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miwrmk"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "WO #"
    end

    attribute :mremark, :string, description: "Remark"
  end

  relationships do
    belongs_to :work_order, AccountMate.Manufacturing.WorkOrder do
      source_attribute :cwono
      destination_attribute :cwono
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_work_order_remark, [:cwono]
  end
end

# Work Order Instruction Resource
defmodule AccountMate.Manufacturing.WorkOrderInstruction do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "miwtin"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :cuid, writable?: false

    attribute :citemno, :string do
      constraints max_length: 20
      allow_nil? false
      description "Item #"
    end

    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      description "WO #"
    end

    attribute :minstr, :string, description: "Instruction"
    attribute :nstep, :integer, description: "Step"
  end

  relationships do
    belongs_to :work_order_line_item, AccountMate.Manufacturing.WorkOrderLineItem do
      source_attribute :cuid
      destination_attribute :cuid
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Manufacturing System Configuration Resource
defmodule AccountMate.Manufacturing.SystemConfiguration do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "misyst"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cmisetup, :string do
      constraints max_length: 1
      allow_nil? false
      default: "C"
      description "Setup Status"
    end

    attribute :cperiod, :string do
      constraints max_length: 6
      allow_nil? false
      description "Current Period"
    end

    attribute :cwono, :string do
      constraints max_length: 10
      allow_nil? false
      default: "1000000001"
      description "Next WO #"
    end

    attribute :cjobno, :string do
      constraints max_length: 10
      allow_nil? false
      default: "1000000001"
      description "Next Job #"
    end

    attribute :cinvwipacc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Inventory Work-in-process Account ID"
    end

    attribute :cmacwipacc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Machine Work-in-process Account ID"
    end

    attribute :clabwipacc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Labor Work-in-process Account ID"
    end

    attribute :cmacclracc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Machine Clearing Account ID"
    end

    attribute :clabclracc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Labor Clearing Account ID"
    end

    attribute :cprovaracc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Product Variance Account ID"
    end

    attribute :cohallacc, :string do
      constraints max_length: 30
      allow_nil? false
      description "Overhead Allowance Account ID"
    end

    attribute :cwordrpt, :string do
      constraints max_length: 1
      default: "P"
      description "Work Order Report Option ('P' – Preprinted, 'B' – Blank form)"
    end

    attribute :crslprpt, :string do
      constraints max_length: 1
      default: "P"
      description "Routing Slip Report Option ('P' – Preprinted, 'B' – Blank form)"
    end

    attribute :cpslprpt, :string do
      constraints max_length: 1
      default: "P"
      description "Production Slip Report Option ('P' – Preprinted, 'B' – Blank form)"
    end

    attribute :cscrapacc, :string do
      constraints max_length: 30
      description "Scrap Expense Account ID"
    end

    attribute :dpurgwo, :date, description: "WO Records Purge Date"
    attribute :dpurgiadj, :date, description: "Inventory Adjustment Purge Date"
    attribute :tlasttfer, :utc_datetime, description: "Last Transfer Date"

    # Boolean flags for various system options
    attribute :lwordlogo, :boolean, default: false, description: "Print Logo on Work Orders"
    attribute :lwordcomp, :boolean, default: false, description: "Print Company Name on Work Orders"
    attribute :lworddspc, :boolean, default: false, description: "Double-space Line Items on Work Orders"
    attribute :lrslplogo, :boolean, default: false, description: "Print Logo on Routing Slips"
    attribute :lrslpcomp, :boolean, default: false, description: "Print Company Name on Routing Slips"
    attribute :lrslpdspc, :boolean, default: false, description: "Double-space Line Items on Routing Slips"
    attribute :lpslplogo, :boolean, default: false, description: "Print Logo on Production Slips"
    attribute :lpslpcomp, :boolean, default: false, description: "Print Company Name on Routing Slip"
    attribute :lpslpdspc, :boolean, default: false, description: "Double-space Line Items on Production Slips"
    attribute :lcpwodesc, :boolean, default: true, description: "Copy Line Items Description on Work Order"
    attribute :lcpwormk, :boolean, default: true, description: "Copy Work Order Line Item Remark"
    attribute :lprtword, :boolean, default: true, description: "Print Work Order"
    attribute :lprtrslp, :boolean, default: false, description: "Print Routing Slip"
    attribute :lprtpslp, :boolean, default: false, description: "Print Production Slip"
    attribute :lowheader, :boolean, default: true, description: "Overwrite Work Order Header"
    attribute :lwofromso, :boolean, default: true, description: "Create WO from SO"
    attribute :luseonhand, :boolean, default: true, description: "Use Existing On-hand Qty"
    attribute :lchkonhand, :boolean, default: true, description: "Check On-hand Qty"
    attribute :lallowneg, :boolean, default: false, description: "Allow Negative On-hand Qty"
    attribute :lreqwip, :boolean, default: true, description: "Require Work-in-process"
    attribute :ldefserno, :boolean, default: true, description: "Default Serial #"
    attribute :lautowo, :boolean, default: false, description: "System-Generated WO #"
    attribute :lcpsodesc, :boolean, default: true, description: "Copy SO Line Item Description"
    attribute :lcpsormk, :boolean, default: true, description: "Copy SO Line Item Remark"
    attribute :lcpsobqty, :boolean, default: true, description: "Copy SO Backorder Qty"
    attribute :lmreqdate, :boolean, default: false, description: "Multiple Request Date"

    # Integer configuration options
    attribute :npostwip, :integer, default: 1, description: "Post Work-in-process (1 – No Posting, 2 – Always Post, 3 – Prompt for Posting)"
    attribute :nexpwo, :integer, default: 1, description: "Explode Work Orders (1 – No Explosion, 2 – Always Explode, 3 – Prompt for Explosion)"
    attribute :nusestd, :integer, default: 1, description: "Standard Cost Used (1 – Actual Cost, 2 – Standard Cost, 3 – Standard Cost for Masters Only)"
    attribute :noverhead, :integer, default: 1, description: "Overhead Cost Calculation (1 – No Calculation, 2 – By Flat Amount, 3 – By Percentage Rate)"
    attribute :npostprop, :integer, default: 1, description: "Post Proportional Components (1 – No Proportionate posting, 2 – Always Post Proportionately, 3 – Prompt for Proportionate Posting)"

    # Text fields for labels
    attribute :mwordlbl, :string, description: "WO Copy Labels"
    attribute :mrslplbl, :string, description: "Routing Slip Copy Labels"
    attribute :mpslplbl, :string, description: "Production Slip Copy Labels"
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
