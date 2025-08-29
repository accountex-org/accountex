# OWL Ontology for Accounts Payables Domain

Based on the Accountex modular Elixir ERP system architecture using Ash framework, Jido for agentic work, and Commanded for event sourcing, this document presents a comprehensive OWL ontology for the Accounts Payables domain.

## Complete OWL Ontology

```turtle
@prefix : <http://accountex.org/ontology/accounts-payables#> .
@prefix ap: <http://accountex.org/ontology/accounts-payables#> .
@prefix core: <http://accountex.org/ontology/core#> .
@prefix agent: <http://accountex.org/ontology/agent#> .
@prefix event: <http://accountex.org/ontology/event#> .
@prefix mod: <http://accountex.org/ontology/module#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xml: <http://www.w3.org/XML/1998/namespace> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix schema: <https://schema.org/> .
@prefix fibo-fnd: <https://spec.edmcouncil.org/fibo/ontology/FND/> .
@prefix fibo-fbc: <https://spec.edmcouncil.org/fibo/ontology/FBC/> .
@prefix time: <http://www.w3.org/2006/time#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix gr: <http://purl.org/goodrelations/v1#> .

# ============================================================================
# Ontology Declaration
# ============================================================================

<http://accountex.org/ontology/accounts-payables> a owl:Ontology ;
    owl:versionIRI <http://accountex.org/ontology/accounts-payables/1.0> ;
    dcterms:title "Accountex Accounts Payables Domain Ontology"@en ;
    dcterms:description "OWL ontology for the Accounts Payables domain of an Elixir-based accounting and ERP system using Ash framework, Jido agents, and Commanded event sourcing"@en ;
    dcterms:creator "Accountex Development Team" ;
    dcterms:created "2025-01-01"^^xsd:date ;
    dcterms:license <http://opensource.org/licenses/MIT> ;
    owl:imports <http://xmlns.com/foaf/0.1/> ,
                <http://purl.org/dc/terms/> ,
                <http://www.w3.org/2006/time> ,
                <http://www.w3.org/ns/prov> ,
                <http://purl.org/goodrelations/v1> ;
    rdfs:comment "This ontology models the Accounts Payables domain for a modular, event-sourced accounting and ERP system with agentic capabilities"@en .

# ============================================================================
# Core Accounts Payables Classes
# ============================================================================

ap:AccountsPayableModule a owl:Class ;
    rdfs:label "Accounts Payable Module"@en ;
    rdfs:comment "The pluggable application module managing vendor relationships, purchase invoicing, payment processing, and financial compliance"@en ;
    rdfs:subClassOf mod:PluggableApplication ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:managesVendors ;
        owl:someValuesFrom ap:VendorAccount
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:processesInvoices ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

# ============================================================================
# Vendor Management Classes
# ============================================================================

ap:VendorAccount a owl:Class ;
    rdfs:label "Vendor Account"@en ;
    rdfs:comment "A business entity that supplies goods or services to the organization"@en ;
    rdfs:subClassOf foaf:Organization, gr:BusinessEntity ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasVendorIdentificationNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasVendorStatus ;
        owl:someValuesFrom ap:VendorAccountStatus
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasPaymentTerms ;
        owl:someValuesFrom ap:PaymentTerms
    ] .

ap:VendorMailingAddress a owl:Class ;
    rdfs:label "Vendor Mailing Address"@en ;
    rdfs:comment "A mailing address associated with a vendor account"@en ;
    rdfs:subClassOf schema:PostalAddress ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:belongsToVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] .

ap:VendorContactPerson a owl:Class ;
    rdfs:label "Vendor Contact Person"@en ;
    rdfs:comment "A person who serves as a contact point for a vendor"@en ;
    rdfs:subClassOf foaf:Person ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:representsVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] .

ap:VendorAccountStatus a owl:Class ;
    rdfs:label "Vendor Account Status"@en ;
    rdfs:comment "The current status of a vendor account"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Active ap:Inactive ap:Suspended ap:PendingApproval)
    ] .

# ============================================================================
# Invoice Management Classes
# ============================================================================

ap:PurchaseInvoice a owl:Class ;
    rdfs:label "Purchase Invoice"@en ;
    rdfs:comment "An invoice received from a vendor for goods or services purchased"@en ;
    rdfs:subClassOf gr:Invoice, fibo-fbc:FinancialDocument ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasInvoiceControlNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:issuedByVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasInvoicePaymentStatus ;
        owl:someValuesFrom ap:InvoicePaymentStatus
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasInvoiceApprovalStatus ;
        owl:someValuesFrom ap:InvoiceApprovalStatus
    ] .

ap:InvoiceGeneralLedgerDistribution a owl:Class ;
    rdfs:label "Invoice GL Distribution"@en ;
    rdfs:comment "The distribution of invoice amounts to general ledger accounts"@en ;
    rdfs:subClassOf fibo-fbc:AccountingEntry ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:distributesInvoice ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasGLAccountNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

ap:InvoiceFinanceCharge a owl:Class ;
    rdfs:label "Invoice Finance Charge"@en ;
    rdfs:comment "Finance charges applied to overdue invoices"@en ;
    rdfs:subClassOf fibo-fbc:FinancialCharge ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:appliedToInvoice ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

ap:InvoicePaymentStatus a owl:Class ;
    rdfs:label "Invoice Payment Status"@en ;
    rdfs:comment "The payment status of a purchase invoice"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Unpaid ap:PartiallyPaid ap:Paid ap:Voided ap:Cancelled)
    ] .

ap:InvoiceApprovalStatus a owl:Class ;
    rdfs:label "Invoice Approval Status"@en ;
    rdfs:comment "The approval status of a purchase invoice"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Draft ap:PendingApproval ap:Approved ap:Rejected)
    ] .

# ============================================================================
# Payment Management Classes
# ============================================================================

ap:VendorPaymentCheck a owl:Class ;
    rdfs:label "Vendor Payment Check"@en ;
    rdfs:comment "A payment made to a vendor via check or electronic transfer"@en ;
    rdfs:subClassOf fibo-fbc:Payment, gr:PaymentMethod ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasCheckSequenceNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:paidToVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasCheckProcessingStatus ;
        owl:someValuesFrom ap:CheckProcessingStatus
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasBankReconciliationStatus ;
        owl:someValuesFrom ap:BankReconciliationStatus
    ] .

ap:CheckInvoiceApplication a owl:Class ;
    rdfs:label "Check Invoice Application"@en ;
    rdfs:comment "The application of a payment check to specific invoices"@en ;
    rdfs:subClassOf fibo-fbc:PaymentApplication ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:appliesCheck ;
        owl:someValuesFrom ap:VendorPaymentCheck
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:appliesToInvoice ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

ap:ElectronicFundsTransfer a owl:Class ;
    rdfs:label "Electronic Funds Transfer"@en ;
    rdfs:comment "An electronic payment method for vendor payments"@en ;
    rdfs:subClassOf ap:VendorPaymentCheck, gr:PaymentMethodCreditTransfer ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasTransferReference ;
        owl:someValuesFrom xsd:string
    ] .

ap:CheckProcessingStatus a owl:Class ;
    rdfs:label "Check Processing Status"@en ;
    rdfs:comment "The processing status of a vendor payment check"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Printed ap:Manual ap:Electronic ap:CheckVoided)
    ] .

ap:BankReconciliationStatus a owl:Class ;
    rdfs:label "Bank Reconciliation Status"@en ;
    rdfs:comment "The bank reconciliation status of a payment"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Outstanding ap:Cleared ap:ReconciliationVoided ap:ReconciliationCancelled)
    ] .

# ============================================================================
# Tax Reporting Classes
# ============================================================================

ap:TaxForm1099Report a owl:Class ;
    rdfs:label "Tax Form 1099 Report"@en ;
    rdfs:comment "IRS Form 1099 reporting for vendor payments"@en ;
    rdfs:subClassOf fibo-fbc:TaxDocument ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:reportsForVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasTaxYear ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

ap:TaxForm1099Update a owl:Class ;
    rdfs:label "Tax Form 1099 Update"@en ;
    rdfs:comment "Updates or corrections to 1099 tax forms"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:updates1099Report ;
        owl:someValuesFrom ap:TaxForm1099Report
    ] .

# ============================================================================
# Recurring Transaction Classes
# ============================================================================

ap:RecurringInvoiceTemplate a owl:Class ;
    rdfs:label "Recurring Invoice Template"@en ;
    rdfs:comment "A template for automatically generating recurring invoices"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasRecurrenceFrequency ;
        owl:someValuesFrom ap:RecurrenceFrequency
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:forVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] .

ap:RecurringInvoiceDistribution a owl:Class ;
    rdfs:label "Recurring Invoice Distribution"@en ;
    rdfs:comment "GL distribution for recurring invoice templates"@en ;
    rdfs:subClassOf ap:InvoiceGeneralLedgerDistribution ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:belongsToTemplate ;
        owl:someValuesFrom ap:RecurringInvoiceTemplate
    ] .

ap:RecurrenceFrequency a owl:Class ;
    rdfs:label "Recurrence Frequency"@en ;
    rdfs:comment "The frequency of recurring transactions"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (ap:Monthly ap:Quarterly ap:SemiAnnually ap:Annually)
    ] .

# ============================================================================
# Purchase Order Classes
# ============================================================================

ap:PurchaseOrderAccrual a owl:Class ;
    rdfs:label "Purchase Order Accrual"@en ;
    rdfs:comment "Accrual tracking for purchase orders matched to invoices"@en ;
    rdfs:subClassOf fibo-fbc:Accrual ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:matchesWithInvoice ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

ap:PurchaseOrderAccrualQuantity a owl:Class ;
    rdfs:label "Purchase Order Accrual Quantity"@en ;
    rdfs:comment "Quantity tracking for purchase order accruals"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:trackedByAccrual ;
        owl:someValuesFrom ap:PurchaseOrderAccrual
    ] .

# ============================================================================
# Configuration Classes
# ============================================================================

ap:SystemConfiguration a owl:Class ;
    rdfs:label "AP System Configuration"@en ;
    rdfs:comment "Configuration settings for the Accounts Payables module"@en ;
    rdfs:subClassOf core:SystemConfiguration ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasConfigurationName ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

ap:PaymentTerms a owl:Class ;
    rdfs:label "Payment Terms"@en ;
    rdfs:comment "Payment terms configuration for vendors"@en ;
    rdfs:subClassOf gr:PaymentTermsSpecification ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasNetPaymentDays ;
        owl:someValuesFrom xsd:integer
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasDiscountPercentage ;
        owl:someValuesFrom xsd:decimal
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty ap:hasDiscountDays ;
        owl:someValuesFrom xsd:integer
    ] .

# ============================================================================
# Agent Classes for AP Domain
# ============================================================================

agent:AccountsPayableAgent a owl:Class ;
    rdfs:label "Accounts Payable Agent"@en ;
    rdfs:comment "An agent specialized for accounts payable operations"@en ;
    rdfs:subClassOf agent:Agent ;
    owl:disjointUnionOf (
        agent:InvoiceProcessingAgent
        agent:PaymentProcessingAgent
        agent:VendorManagementAgent
        agent:TaxComplianceAgent
        agent:ReconciliationAgent
    ) .

agent:InvoiceProcessingAgent a owl:Class ;
    rdfs:label "Invoice Processing Agent"@en ;
    rdfs:comment "Agent responsible for processing and validating invoices"@en ;
    rdfs:subClassOf agent:AccountsPayableAgent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:processes ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

agent:PaymentProcessingAgent a owl:Class ;
    rdfs:label "Payment Processing Agent"@en ;
    rdfs:comment "Agent responsible for processing vendor payments"@en ;
    rdfs:subClassOf agent:AccountsPayableAgent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:processes ;
        owl:someValuesFrom ap:VendorPaymentCheck
    ] .

# ============================================================================
# Event Sourcing Classes for AP Domain
# ============================================================================

event:AccountsPayableEvent a owl:Class ;
    rdfs:label "Accounts Payable Event"@en ;
    rdfs:comment "Domain events specific to accounts payable operations"@en ;
    rdfs:subClassOf event:Event ;
    owl:disjointUnionOf (
        event:VendorCreatedEvent
        event:InvoiceReceivedEvent
        event:InvoiceApprovedEvent
        event:PaymentIssuedEvent
        event:PaymentClearedEvent
        event:InvoiceVoidedEvent
    ) .

event:VendorCreatedEvent a owl:Class ;
    rdfs:label "Vendor Created Event"@en ;
    rdfs:comment "Event emitted when a new vendor is created"@en ;
    rdfs:subClassOf event:AccountsPayableEvent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:createsVendor ;
        owl:someValuesFrom ap:VendorAccount
    ] .

event:InvoiceReceivedEvent a owl:Class ;
    rdfs:label "Invoice Received Event"@en ;
    rdfs:comment "Event emitted when an invoice is received from a vendor"@en ;
    rdfs:subClassOf event:AccountsPayableEvent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:receivesInvoice ;
        owl:someValuesFrom ap:PurchaseInvoice
    ] .

event:PaymentIssuedEvent a owl:Class ;
    rdfs:label "Payment Issued Event"@en ;
    rdfs:comment "Event emitted when a payment is issued to a vendor"@en ;
    rdfs:subClassOf event:AccountsPayableEvent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:issuesPayment ;
        owl:someValuesFrom ap:VendorPaymentCheck
    ] .

# ============================================================================
# Object Properties
# ============================================================================

# Vendor Management Properties
ap:managesVendors a owl:ObjectProperty ;
    rdfs:label "manages vendors"@en ;
    rdfs:domain ap:AccountsPayableModule ;
    rdfs:range ap:VendorAccount ;
    rdfs:comment "Relates the AP module to vendor accounts it manages"@en .

ap:hasMailingAddress a owl:ObjectProperty ;
    rdfs:label "has mailing address"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:VendorMailingAddress ;
    rdfs:comment "Associates a vendor with mailing addresses"@en .

ap:hasContactPerson a owl:ObjectProperty ;
    rdfs:label "has contact person"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:VendorContactPerson ;
    rdfs:comment "Associates a vendor with contact persons"@en .

ap:belongsToVendor a owl:ObjectProperty ;
    rdfs:label "belongs to vendor"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (ap:VendorMailingAddress ap:VendorContactPerson)
    ] ;
    rdfs:range ap:VendorAccount ;
    owl:inverseOf ap:hasMailingAddress ;
    rdfs:comment "Associates an address or contact with a vendor"@en .

ap:representsVendor a owl:ObjectProperty ;
    rdfs:label "represents vendor"@en ;
    rdfs:domain ap:VendorContactPerson ;
    rdfs:range ap:VendorAccount ;
    rdfs:comment "Indicates which vendor a contact person represents"@en .

# Invoice Properties
ap:processesInvoices a owl:ObjectProperty ;
    rdfs:label "processes invoices"@en ;
    rdfs:domain ap:AccountsPayableModule ;
    rdfs:range ap:PurchaseInvoice ;
    rdfs:comment "Relates the AP module to invoices it processes"@en .

ap:issuedByVendor a owl:ObjectProperty ;
    rdfs:label "issued by vendor"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:VendorAccount ;
    rdfs:comment "Relates an invoice to the vendor that issued it"@en .

ap:receivesInvoice a owl:ObjectProperty ;
    rdfs:label "receives invoice"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:PurchaseInvoice ;
    owl:inverseOf ap:issuedByVendor ;
    rdfs:comment "Relates a vendor to invoices received from them"@en .

ap:hasGLDistribution a owl:ObjectProperty ;
    rdfs:label "has GL distribution"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:InvoiceGeneralLedgerDistribution ;
    rdfs:comment "Associates an invoice with its GL distributions"@en .

ap:distributesInvoice a owl:ObjectProperty ;
    rdfs:label "distributes invoice"@en ;
    rdfs:domain ap:InvoiceGeneralLedgerDistribution ;
    rdfs:range ap:PurchaseInvoice ;
    owl:inverseOf ap:hasGLDistribution ;
    rdfs:comment "Relates a GL distribution to its source invoice"@en .

ap:hasFinanceCharge a owl:ObjectProperty ;
    rdfs:label "has finance charge"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:InvoiceFinanceCharge ;
    rdfs:comment "Associates an invoice with finance charges"@en .

ap:appliedToInvoice a owl:ObjectProperty ;
    rdfs:label "applied to invoice"@en ;
    rdfs:domain ap:InvoiceFinanceCharge ;
    rdfs:range ap:PurchaseInvoice ;
    owl:inverseOf ap:hasFinanceCharge ;
    rdfs:comment "Relates a finance charge to the invoice it applies to"@en .

# Payment Properties
ap:receivesPayment a owl:ObjectProperty ;
    rdfs:label "receives payment"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:VendorPaymentCheck ;
    rdfs:comment "Relates a vendor to payments received"@en .

ap:paidToVendor a owl:ObjectProperty ;
    rdfs:label "paid to vendor"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range ap:VendorAccount ;
    owl:inverseOf ap:receivesPayment ;
    rdfs:comment "Relates a payment to the vendor it was paid to"@en .

ap:hasCheckApplication a owl:ObjectProperty ;
    rdfs:label "has check application"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range ap:CheckInvoiceApplication ;
    rdfs:comment "Associates a check with its invoice applications"@en .

ap:appliesCheck a owl:ObjectProperty ;
    rdfs:label "applies check"@en ;
    rdfs:domain ap:CheckInvoiceApplication ;
    rdfs:range ap:VendorPaymentCheck ;
    owl:inverseOf ap:hasCheckApplication ;
    rdfs:comment "Relates an application to the check being applied"@en .

ap:appliesToInvoice a owl:ObjectProperty ;
    rdfs:label "applies to invoice"@en ;
    rdfs:domain ap:CheckInvoiceApplication ;
    rdfs:range ap:PurchaseInvoice ;
    rdfs:comment "Relates a check application to the invoice it applies to"@en .

ap:paidByCheck a owl:ObjectProperty ;
    rdfs:label "paid by check"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:CheckInvoiceApplication ;
    owl:inverseOf ap:appliesToInvoice ;
    rdfs:comment "Relates an invoice to check applications that pay it"@en .

ap:processedAsEFT a owl:ObjectProperty ;
    rdfs:label "processed as EFT"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range ap:ElectronicFundsTransfer ;
    rdfs:comment "Indicates a check was processed as an electronic transfer"@en .

# Tax Reporting Properties
ap:requires1099Reporting a owl:ObjectProperty ;
    rdfs:label "requires 1099 reporting"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:TaxForm1099Report ;
    rdfs:comment "Associates a vendor with required 1099 reports"@en .

ap:reportsForVendor a owl:ObjectProperty ;
    rdfs:label "reports for vendor"@en ;
    rdfs:domain ap:TaxForm1099Report ;
    rdfs:range ap:VendorAccount ;
    owl:inverseOf ap:requires1099Reporting ;
    rdfs:comment "Relates a 1099 report to the vendor it reports for"@en .

ap:has1099Update a owl:ObjectProperty ;
    rdfs:label "has 1099 update"@en ;
    rdfs:domain ap:TaxForm1099Report ;
    rdfs:range ap:TaxForm1099Update ;
    rdfs:comment "Associates a 1099 report with its updates"@en .

ap:updates1099Report a owl:ObjectProperty ;
    rdfs:label "updates 1099 report"@en ;
    rdfs:domain ap:TaxForm1099Update ;
    rdfs:range ap:TaxForm1099Report ;
    owl:inverseOf ap:has1099Update ;
    rdfs:comment "Relates an update to the 1099 report it updates"@en .

# Recurring Transaction Properties
ap:usesRecurringTemplate a owl:ObjectProperty ;
    rdfs:label "uses recurring template"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:RecurringInvoiceTemplate ;
    rdfs:comment "Associates a vendor with recurring invoice templates"@en .

ap:forVendor a owl:ObjectProperty ;
    rdfs:label "for vendor"@en ;
    rdfs:domain ap:RecurringInvoiceTemplate ;
    rdfs:range ap:VendorAccount ;
    owl:inverseOf ap:usesRecurringTemplate ;
    rdfs:comment "Relates a recurring template to its vendor"@en .

ap:hasRecurringDistribution a owl:ObjectProperty ;
    rdfs:label "has recurring distribution"@en ;
    rdfs:domain ap:RecurringInvoiceTemplate ;
    rdfs:range ap:RecurringInvoiceDistribution ;
    rdfs:comment "Associates a template with its distributions"@en .

ap:belongsToTemplate a owl:ObjectProperty ;
    rdfs:label "belongs to template"@en ;
    rdfs:domain ap:RecurringInvoiceDistribution ;
    rdfs:range ap:RecurringInvoiceTemplate ;
    owl:inverseOf ap:hasRecurringDistribution ;
    rdfs:comment "Relates a distribution to its template"@en .

# Purchase Order Properties
ap:matchesWithInvoice a owl:ObjectProperty ;
    rdfs:label "matches with invoice"@en ;
    rdfs:domain ap:PurchaseOrderAccrual ;
    rdfs:range ap:PurchaseInvoice ;
    rdfs:comment "Relates a PO accrual to the matching invoice"@en .

ap:hasAccrualQuantity a owl:ObjectProperty ;
    rdfs:label "has accrual quantity"@en ;
    rdfs:domain ap:PurchaseOrderAccrual ;
    rdfs:range ap:PurchaseOrderAccrualQuantity ;
    rdfs:comment "Associates an accrual with quantity tracking"@en .

ap:trackedByAccrual a owl:ObjectProperty ;
    rdfs:label "tracked by accrual"@en ;
    rdfs:domain ap:PurchaseOrderAccrualQuantity ;
    rdfs:range ap:PurchaseOrderAccrual ;
    owl:inverseOf ap:hasAccrualQuantity ;
    rdfs:comment "Relates a quantity to its accrual"@en .

# Status Properties
ap:hasVendorStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has vendor status"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:VendorAccountStatus ;
    rdfs:comment "Current status of a vendor account"@en .

ap:hasInvoicePaymentStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice payment status"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:InvoicePaymentStatus ;
    rdfs:comment "Payment status of an invoice"@en .

ap:hasInvoiceApprovalStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice approval status"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range ap:InvoiceApprovalStatus ;
    rdfs:comment "Approval status of an invoice"@en .

ap:hasCheckProcessingStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has check processing status"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range ap:CheckProcessingStatus ;
    rdfs:comment "Processing status of a payment check"@en .

ap:hasBankReconciliationStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has bank reconciliation status"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range ap:BankReconciliationStatus ;
    rdfs:comment "Bank reconciliation status of a payment"@en .

ap:hasPaymentTerms a owl:ObjectProperty ;
    rdfs:label "has payment terms"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range ap:PaymentTerms ;
    rdfs:comment "Payment terms associated with a vendor"@en .

ap:hasRecurrenceFrequency a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has recurrence frequency"@en ;
    rdfs:domain ap:RecurringInvoiceTemplate ;
    rdfs:range ap:RecurrenceFrequency ;
    rdfs:comment "Frequency of recurring invoice generation"@en .

# Configuration Properties
ap:configures a owl:ObjectProperty ;
    rdfs:label "configures"@en ;
    rdfs:domain ap:SystemConfiguration ;
    rdfs:range ap:VendorAccount ;
    rdfs:comment "Relates system configuration to vendor accounts"@en .

# ============================================================================
# Data Properties
# ============================================================================

# Vendor Identifiers and Attributes
ap:hasVendorIdentificationNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has vendor identification number"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a vendor (max 9 characters)"@en .

ap:hasCompanyLegalName a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has company legal name"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:string ;
    rdfs:comment "Legal name of the vendor company"@en .

ap:hasCustomerAccountReference a owl:DatatypeProperty ;
    rdfs:label "has customer account reference"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:string ;
    rdfs:comment "Our account number with the vendor"@en .

ap:hasVendorClassification a owl:DatatypeProperty ;
    rdfs:label "has vendor classification"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:string ;
    rdfs:comment "Classification type code for the vendor"@en .

ap:requiresCashOnDelivery a owl:DatatypeProperty ;
    rdfs:label "requires cash on delivery"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if vendor requires COD payment"@en .

ap:isFederal1099Eligible a owl:DatatypeProperty ;
    rdfs:label "is federal 1099 eligible"@en ;
    rdfs:domain ap:VendorAccount ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if vendor is eligible for 1099 reporting"@en .

# Invoice Properties
ap:hasInvoiceControlNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice control number"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:string ;
    rdfs:comment "Internal control number for the invoice"@en .

ap:hasVendorInvoiceReference a owl:DatatypeProperty ;
    rdfs:label "has vendor invoice reference"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:string ;
    rdfs:comment "Vendor's invoice number"@en .

ap:hasPurchaseOrderReference a owl:DatatypeProperty ;
    rdfs:label "has purchase order reference"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:string ;
    rdfs:comment "Related purchase order number"@en .

ap:hasInvoiceTransactionDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice transaction date"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:date ;
    rdfs:comment "Date of the invoice transaction"@en .

ap:hasGeneralLedgerPostingDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has GL posting date"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:date ;
    rdfs:comment "Date invoice is posted to general ledger"@en .

ap:hasPaymentDueDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has payment due date"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:date ;
    rdfs:comment "Date payment is due"@en .

ap:hasEarlyPaymentDiscountDate a owl:DatatypeProperty ;
    rdfs:label "has early payment discount date"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:date ;
    rdfs:comment "Last date to qualify for early payment discount"@en .

# Amount Properties
ap:hasInvoiceOriginalAmount a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice original amount"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Original amount of the invoice"@en .

ap:hasTotalAmountPaidToDate a owl:DatatypeProperty ;
    rdfs:label "has total amount paid to date"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Total amount paid against the invoice"@en .

ap:hasOutstandingBalanceAmount a owl:DatatypeProperty ;
    rdfs:label "has outstanding balance amount"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Remaining balance on the invoice"@en .

ap:hasAvailableDiscountAmount a owl:DatatypeProperty ;
    rdfs:label "has available discount amount"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Available discount if paid early"@en .

ap:hasFederal1099ReportableAmount a owl:DatatypeProperty ;
    rdfs:label "has federal 1099 reportable amount"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Amount reportable on 1099 form"@en .

# Payment Check Properties
ap:hasCheckSequenceNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has check sequence number"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:string ;
    rdfs:comment "Sequence number of the check"@en .

ap:hasCheckIssueDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has check issue date"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:date ;
    rdfs:comment "Date the check was issued"@en .

ap:hasCheckReconciliationDate a owl:DatatypeProperty ;
    rdfs:label "has check reconciliation date"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:date ;
    rdfs:comment "Date the check was reconciled"@en .

ap:hasBankAccountCode a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has bank account code"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:string ;
    rdfs:comment "Bank account code for the payment"@en .

ap:hasCheckGrossAmount a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has check gross amount"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Gross amount of the check"@en .

ap:hasDiscountAmountTaken a owl:DatatypeProperty ;
    rdfs:label "has discount amount taken"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Discount amount taken on payment"@en .

ap:hasNetPaymentAmount a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has net payment amount"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Net amount of the payment"@en .

ap:hasCheckClearedAmount a owl:DatatypeProperty ;
    rdfs:label "has check cleared amount"@en ;
    rdfs:domain ap:VendorPaymentCheck ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Amount cleared by the bank"@en .

# GL Distribution Properties
ap:hasGLAccountNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has GL account number"@en ;
    rdfs:domain ap:InvoiceGeneralLedgerDistribution ;
    rdfs:range xsd:string ;
    rdfs:comment "General ledger account number"@en .

ap:hasDistributionAmount a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has distribution amount"@en ;
    rdfs:domain ap:InvoiceGeneralLedgerDistribution ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Amount distributed to GL account"@en .

ap:hasDistributionDescription a owl:DatatypeProperty ;
    rdfs:label "has distribution description"@en ;
    rdfs:domain ap:InvoiceGeneralLedgerDistribution ;
    rdfs:range xsd:string ;
    rdfs:comment "Description of the distribution"@en .

ap:hasDistributionPostingDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has distribution posting date"@en ;
    rdfs:domain ap:InvoiceGeneralLedgerDistribution ;
    rdfs:range xsd:date ;
    rdfs:comment "Date distribution is posted"@en .

# Payment Terms Properties
ap:hasEarlyPaymentDiscountPercentage a owl:DatatypeProperty ;
    rdfs:label "has early payment discount percentage"@en ;
    rdfs:domain ap:PaymentTerms ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Discount percentage for early payment"@en .

ap:hasDiscountDays a owl:DatatypeProperty ;
    rdfs:label "has discount days"@en ;
    rdfs:domain ap:PaymentTerms ;
    rdfs:range xsd:integer ;
    rdfs:comment "Days to qualify for discount"@en .

ap:hasNetPaymentDays a owl:DatatypeProperty ;
    rdfs:label "has net payment days"@en ;
    rdfs:domain ap:PaymentTerms ;
    rdfs:range xsd:integer ;
    rdfs:comment "Net payment due days"@en .

# Tax Properties
ap:hasTaxYear a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has tax year"@en ;
    rdfs:domain ap:TaxForm1099Report ;
    rdfs:range xsd:gYear ;
    rdfs:comment "Tax year for the 1099 report"@en .

# Configuration Properties
ap:hasConfigurationName a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has configuration name"@en ;
    rdfs:domain ap:SystemConfiguration ;
    rdfs:range xsd:string ;
    rdfs:comment "Name of the configuration"@en .

ap:hasAPLiabilityAccount a owl:DatatypeProperty ;
    rdfs:label "has AP liability account"@en ;
    rdfs:domain ap:SystemConfiguration ;
    rdfs:range xsd:string ;
    rdfs:comment "General ledger account for AP liability"@en .

ap:hasDefaultStateTaxPercentage a owl:DatatypeProperty ;
    rdfs:label "has default state tax percentage"@en ;
    rdfs:domain ap:SystemConfiguration ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Default state tax percentage"@en .

ap:isGLIntegrationEnabled a owl:DatatypeProperty ;
    rdfs:label "is GL integration enabled"@en ;
    rdfs:domain ap:SystemConfiguration ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if GL integration is enabled"@en .

# Calculated Properties
ap:isDaysOverdue a owl:DatatypeProperty ;
    rdfs:label "is days overdue"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:integer ;
    rdfs:comment "Number of days invoice is overdue"@en .

ap:isOverdue a owl:DatatypeProperty ;
    rdfs:label "is overdue"@en ;
    rdfs:domain ap:PurchaseInvoice ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if invoice is overdue"@en .

# ============================================================================
# Constraints and Axioms
# ============================================================================

# Disjointness Axioms
[] a owl:AllDisjointClasses ;
    owl:members (
        ap:VendorAccount
        ap:PurchaseInvoice
        ap:VendorPaymentCheck
        ap:TaxForm1099Report
    ) .

[] a owl:AllDisjointClasses ;
    owl:members (
        agent:InvoiceProcessingAgent
        agent:PaymentProcessingAgent
        agent:VendorManagementAgent
        agent:TaxComplianceAgent
        agent:ReconciliationAgent
    ) .

# Cardinality Constraints
ap:VendorAccount rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty ap:hasVendorStatus ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

ap:PurchaseInvoice rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty ap:issuedByVendor ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

ap:VendorPaymentCheck rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty ap:paidToVendor ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

ap:CheckInvoiceApplication rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty ap:appliesCheck ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] ;
    rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty ap:appliesToInvoice ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

# Property Chains
ap:transitivelyPaysFor a owl:ObjectProperty ;
    rdfs:label "transitively pays for"@en ;
    owl:propertyChainAxiom (ap:hasCheckApplication ap:appliesToInvoice) ;
    rdfs:comment "Check transitively pays for invoices through applications"@en .

# ============================================================================
# SWRL Rules (Optional - for reasoning)
# ============================================================================

# Rule: Mark invoice as overdue
# PurchaseInvoice(?inv) ∧ hasPaymentDueDate(?inv, ?due) ∧ 
# hasInvoicePaymentStatus(?inv, ?status) ∧ (status = Unpaid ∨ status = PartiallyPaid) ∧
# swrlb:lessThan(?due, ?today) → isOverdue(?inv, true)

# Rule: Apply early payment discount
# PurchaseInvoice(?inv) ∧ hasEarlyPaymentDiscountDate(?inv, ?discDate) ∧
# VendorPaymentCheck(?check) ∧ hasCheckIssueDate(?check, ?issueDate) ∧
# swrlb:lessThanOrEqual(?issueDate, ?discDate) → hasDiscountAmountTaken(?check, ?discount)

# Rule: Generate recurring invoice
# RecurringInvoiceTemplate(?template) ∧ hasRecurrenceFrequency(?template, Monthly) ∧
# hasNextGenerationDate(?template, ?nextDate) ∧ swrlb:equal(?nextDate, ?today) →
# generateInvoiceFromTemplate(?template)

# ============================================================================
# Annotations
# ============================================================================

ap:AccountsPayableModule rdfs:seeAlso <https://hexdocs.pm/ash/> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/accounts-payables> .

ap:VendorAccount rdfs:seeAlso <https://spec.edmcouncil.org/fibo/ontology/FBC/ProductsAndServices/ClientsAndAccounts/> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/accounts-payables> .

ap:PurchaseInvoice rdfs:seeAlso <http://purl.org/goodrelations/v1#Invoice> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/accounts-payables> .
```

## Key Features of this Ontology

### Comprehensive Accounts Payables Domain Coverage
The ontology captures all major aspects of the Accounts Payables domain including:
- **Vendor Management**: VendorAccount, VendorMailingAddress, VendorContactPerson with complete status tracking
- **Invoice Processing**: PurchaseInvoice with approval workflows, payment status, and GL distributions
- **Payment Processing**: VendorPaymentCheck, CheckInvoiceApplication, ElectronicFundsTransfer with reconciliation
- **Tax Compliance**: TaxForm1099Report and updates for regulatory requirements
- **Recurring Transactions**: RecurringInvoiceTemplate with frequency-based generation
- **Purchase Order Matching**: PurchaseOrderAccrual for three-way matching

### Integration with Standard Vocabularies
The ontology leverages established vocabularies:
- **FIBO** (Financial Industry Business Ontology) for financial concepts
- **GoodRelations** for commercial transactions and business entities
- **Schema.org** for addresses and organization data
- **FOAF** for people and organizational relationships
- **PROV-O** for audit trails and provenance
- **Dublin Core** for metadata

### Event Sourcing Support for AP Operations
Complete modeling of Commanded event sourcing patterns:
- VendorCreatedEvent, InvoiceReceivedEvent, PaymentIssuedEvent
- Full audit trail capabilities through event sequencing
- Support for event replay and projections
- Integration with saga patterns for payment workflows

### Agent-Based Automation
Specialized agents for AP automation:
- **InvoiceProcessingAgent**: Automated invoice validation and matching
- **PaymentProcessingAgent**: Payment optimization and execution
- **VendorManagementAgent**: Vendor onboarding and management
- **TaxComplianceAgent**: 1099 reporting and tax calculations
- **ReconciliationAgent**: Bank reconciliation automation

### Business Rule Support
The ontology supports complex business rules:
- Early payment discount calculations
- Payment term enforcement
- Invoice approval workflows
- Three-way matching for purchase orders
- Vendor status management

### Ash Framework Alignment
Direct mapping to Ash resources and actions:
- Each OWL class corresponds to an Ash resource
- Properties map to Ash attributes
- Object properties represent Ash relationships
- Status enumerations align with Ash atom types

## Usage Recommendations

### Integration with Core System
- Import core ontology namespaces for system-wide concepts
- Use agent namespace for Jido agent integration
- Leverage event namespace for Commanded event sourcing
- Maintain consistency with module namespace for pluggable architecture

### Financial Standards Compliance
- Extend with additional FIBO ontologies for advanced financial concepts
- Use XBRL taxonomies for financial reporting requirements
- Integrate with ISO 20022 for payment message standards

### Reasoning and Validation
- Use OWL reasoning to validate vendor relationships
- Implement SWRL rules for automated invoice processing
- Apply constraints to ensure data integrity
- Use property chains for transitive payment relationships

### Event-Driven Patterns
- Model all state changes as events
- Maintain complete audit trails through event properties
- Support CQRS with separate read/write models
- Enable temporal queries over payment history

This ontology provides a robust semantic foundation for the Accounts Payables domain, enabling automated reasoning, integration with other financial systems, and comprehensive documentation of the domain model and business rules.
