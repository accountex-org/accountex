# AccountMate 12 Configurator Ash Resources

defmodule AccountMate.Configurator.Master do
  @moduledoc "Configurator Master Table (Scmast)"
  use Ash.Resource

  resource do
    description "Main configuration definitions"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ccfgcode, :string, constraints: [max_length: 10], description: "Configuration Code"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :cstatus, :string, constraints: [max_length: 1], default: "A", description: "Status"
    attribute :chold, :string, constraints: [max_length: 10], description: "Hold Reason"
    attribute :dcreate, :datetime, description: "Created"
    attribute :lhold, :boolean, default: false, description: "Hold"
    attribute :lcurrent, :boolean, default: false, description: "Current Version"
    attribute :nversion, :integer, default: 1, description: "Version #"
    attribute :tmodified, :datetime, description: "Last Modified"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :options, AccountMate.Configurator.Options, destination_attribute: :ncfgid
    has_many :choices, AccountMate.Configurator.Choices, destination_attribute: :ncfgid
    has_many :formulas, AccountMate.Configurator.Formula, destination_attribute: :ncfgid
    has_many :definitions, AccountMate.Configurator.Definition, destination_attribute: :ncfgid
    has_many :rules, AccountMate.Configurator.Rules, destination_attribute: :ncfgid
    has_many :bom_items, AccountMate.Configurator.BillOfMaterials, destination_attribute: :ncfgid
    has_one :notepad, AccountMate.Configurator.MasterNotepad, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.Options do
  @moduledoc "Configurator Options Table (Scopts)"
  use Ash.Resource

  resource do
    description "Configuration options and their properties"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :noptno, :integer, description: "Option #"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :lnumeric, :boolean, default: false, description: "Numeric Option"
    attribute :lowvalue, :boolean, default: false, description: "Allow Overwrite Value"
    attribute :luselist, :boolean, default: false, description: "Use Dropdown List"
    attribute :nruleid, :integer, description: "Rule ID"
    attribute :nseq, :integer, default: 0, description: "Order"
    attribute :nitemidlen, :integer, description: "Item ID Length"
    attribute :ndescidlen, :integer, description: "Description ID Length"
    attribute :nqtydec, :integer, default: 0, description: "Qty Decimals"
    attribute :nfrbase, :integer, default: 0, description: "Fraction Base"
    attribute :ndefvalue, :decimal, precision: 18, scale: 4, default: 0, description: "Default Value"
    attribute :nminvalue, :decimal, precision: 18, scale: 4, default: 0, description: "Minimum Value"
    attribute :nmaxvalue, :decimal, precision: 18, scale: 4, default: 0, description: "Maximum Value"
    attribute :nprice, :decimal, precision: 18, scale: 4, default: 0, description: "Unit Price"
    attribute :nstdcost, :decimal, precision: 18, scale: 4, default: 0, description: "Std Unit Cost"
    attribute :nrtrncost, :decimal, precision: 18, scale: 4, default: 0, description: "Return Unit Cost"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :rule, AccountMate.Configurator.Rules, source_attribute: :nruleid, destination_attribute: :nidno
    has_many :choices, AccountMate.Configurator.Choices, destination_attribute: :noptid
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.Choices do
  @moduledoc "Configurator Choices Table (Scchcs)"
  use Ash.Resource

  resource do
    description "Available choices for configuration options"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :noptid, :integer, description: "Option ID"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :citemid, :string, constraints: [max_length: 20], description: "Item ID"
    attribute :cdescid, :string, constraints: [max_length: 20], description: "Description ID"
    attribute :ldefault, :boolean, default: false, description: "Default"
    attribute :nruleid, :integer, description: "Rule ID"
    attribute :nseq, :integer, default: 0, description: "Order"
    attribute :nvalue, :decimal, precision: 18, scale: 4, default: 0, description: "Value"
    attribute :nprice, :decimal, precision: 18, scale: 4, default: 0, description: "Unit Price"
    attribute :nstdcost, :decimal, precision: 18, scale: 4, default: 0, description: "Std Unit Cost"
    attribute :nrtrncost, :decimal, precision: 18, scale: 4, default: 0, description: "Return Unit Cost"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :option, AccountMate.Configurator.Options, source_attribute: :noptid, destination_attribute: :nidno
    belongs_to :rule, AccountMate.Configurator.Rules, source_attribute: :nruleid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.Formula do
  @moduledoc "Configurator Formula Table (Scform)"
  use Ash.Resource

  resource do
    description "Formulas for calculations and dynamic pricing"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :nformno, :integer, description: "Formula #"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :linvalid, :boolean, default: false, description: "Invalid Formula"
    attribute :nfrbase, :integer, default: 0, description: "Fraction Base"
    attribute :nqtydec, :integer, default: 0, description: "Qty Decimals"
    attribute :nitemidlen, :integer, description: "Item ID Length"
    attribute :ndescidlen, :integer, description: "Description ID Length"
    attribute :nprice, :decimal, precision: 18, scale: 4, default: 0, description: "Unit Price"
    attribute :nstdcost, :decimal, precision: 18, scale: 4, default: 0, description: "Std Unit Cost"
    attribute :nrtrncost, :decimal, precision: 18, scale: 4, default: 0, description: "Return Unit Cost"
    attribute :mtext, :string, description: "Formula Text"
    attribute :mcode, :string, description: "Formula Code"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.Rules do
  @moduledoc "Configurator Rules Table (Scrule)"
  use Ash.Resource

  resource do
    description "Business rules and validation logic"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :nruleno, :integer, description: "Rule #"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :linvalid, :boolean, default: false, description: "Invalid Formula"
    attribute :mtext, :string, description: "Rule Text"
    attribute :mcode, :string, description: "Rule Code"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.Definition do
  @moduledoc "Configurator Definition Table (Scidef)"
  use Ash.Resource

  resource do
    description "Item definitions for configuration components"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :cdefcode, :string, constraints: [max_length: 20], description: "Definition Code"
    attribute :cdescript, :string, constraints: [max_length: 54], description: "Description"
    attribute :lautoadd, :boolean, default: false, description: "Auto Add Items"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    has_many :details, AccountMate.Configurator.DefinitionDetail, destination_attribute: :ndefid
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.DefinitionDetail do
  @moduledoc "Configurator Definition Detail Table (Scidtl)"
  use Ash.Resource

  resource do
    description "Detailed definition components and their relationships"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :ndefid, :integer, description: "Definition ID"
    attribute :cdeftype, :string, constraints: [max_length: 1, one_of: ["I", "D", "P", "R", "S"]], description: "Definition Type"
    attribute :ctype, :string, constraints: [max_length: 1, one_of: ["O", "F", "U"]], description: "Value Type"
    attribute :cuservalue, :string, constraints: [max_length: 1], description: "User Defined Value"
    attribute :ntypeid, :integer, description: "Value ID"
    attribute :ltrsonly, :boolean, default: false, description: "Transaction Only"
    attribute :nseq, :integer, default: 0, description: "Order"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :definition, AccountMate.Configurator.Definition, source_attribute: :ndefid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.BillOfMaterials do
  @moduledoc "Configurator Bill of Materials Table (Scboml)"
  use Ash.Resource

  resource do
    description "Bill of materials components for configurations"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :citemno, :string, constraints: [max_length: 20], description: "Item #"
    attribute :cspeccode1, :string, constraints: [max_length: 10], description: "Spec Code 1"
    attribute :cspeccode2, :string, constraints: [max_length: 10], description: "Spec Code 2"
    attribute :cbomuid, :string, constraints: [max_length: 15], description: "Bill of Materials Unique ID"
    attribute :nformid, :integer, description: "Formula ID"
    attribute :nruleid, :integer, description: "Rule ID"
    attribute :ndefid, :integer, description: "Item Definition ID"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :formula, AccountMate.Configurator.Formula, source_attribute: :nformid, destination_attribute: :nidno
    belongs_to :rule, AccountMate.Configurator.Rules, source_attribute: :nruleid, destination_attribute: :nidno
    belongs_to :definition, AccountMate.Configurator.Definition, source_attribute: :ndefid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.MasterNotepad do
  @moduledoc "Configurator Master Notepad Table (Scmnot)"
  use Ash.Resource

  resource do
    description "Notes and remarks for configurations"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :mnotepad, :string, description: "Remark"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :nidno, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.PrintDefinitions do
  @moduledoc "Configurator Print Definitions Table (Scpdef)"
  use Ash.Resource

  resource do
    description "Print layout definitions for configurations"
  end

  attributes do
    integer_primary_key :nidno, description: "Unique ID"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :cprintkey, :string, constraints: [max_length: 15], description: "Print Key"
    attribute :ctype, :string, constraints: [max_length: 1, one_of: ["O", "F"]], description: "Print Type"
    attribute :ntypeid, :integer, description: "Type ID"
    attribute :nruleid, :integer, description: "Rule ID"
    attribute :nseq, :integer, default: 0, description: "Order"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :rule, AccountMate.Configurator.Rules, source_attribute: :nruleid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.TransactionAnswers do
  @moduledoc "Configurator Transaction Answers Table (Sctrsa)"
  use Ash.Resource

  resource do
    description "Transaction-specific configuration answers"
  end

  attributes do
    attribute :cuid, :string, constraints: [max_length: 15], primary_key?: true, description: "Unique ID"
    attribute :ctrsno, :string, constraints: [max_length: 10], description: "Transaction #"
    attribute :ctrstype, :string, constraints: [max_length: 10], description: "Transaction Type"
    attribute :clineitem, :string, constraints: [max_length: 10], description: "Line Item #"
    attribute :ncfgid, :integer, description: "CFG ID"
    attribute :nversion, :integer, default: 1, description: "Version #"
    attribute :noptid, :integer, description: "Option ID"
    attribute :nvalue, :decimal, precision: 18, scale: 4, default: 0, description: "Value"
    attribute :tmodified, :datetime, description: "Last Modified"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :master, AccountMate.Configurator.Master, source_attribute: :ncfgid, destination_attribute: :nidno
    belongs_to :option, AccountMate.Configurator.Options, source_attribute: :noptid, destination_attribute: :nidno
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AccountMate.Configurator.SystemSetup do
  @moduledoc "Configurator System Setup Table (Scsyst)"
  use Ash.Resource

  resource do
    description "System-wide configurator settings"
  end

  attributes do
    attribute :lbcenabled, :boolean, default: false, description: "Configurator for MI Enabled"
    attribute :lscenabled, :boolean, default: false, description: "Configurator for Sales Enabled"
    attribute :nnxtscboml, :integer, default: 1, description: "Next BOM ID #"
    attribute :nnxtscchcs, :integer, default: 1, description: "Next Choices ID #"
    attribute :nnxtscform, :integer, default: 1, description: "Next Formula ID #"
    attribute :nnxtscidef, :integer, default: 1, description: "Next Item Definition ID #"
    attribute :nnxtscidtl, :integer, default: 1, description: "Next Item Definition Detail ID #"
    attribute :nnxtscmast, :integer, default: 1, description: "Next Master ID #"
    attribute :nnxtscopts, :integer, default: 1, description: "Next Options ID #"
    attribute :nnxtscpdef, :integer, default: 1, description: "Next Print ID #"
    attribute :nnxtscrule, :integer, default: 1, description: "Next Rule ID #"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
