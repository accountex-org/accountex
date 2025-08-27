# Accountex ERP Business Rules Developer Guide

## Introduction

This document provides a comprehensive reference of all business rules (BR-XX-XXX format) defined across the Accountex ERP system. Business rules are organized by module and numbered sequentially to enable precise tracking, implementation validation, and system documentation.

Each business rule is designed to maintain data integrity, enforce business policies, and ensure consistent system behavior across all modules. Developers should reference these rules when implementing features, writing tests, and troubleshooting system behavior.

## Navigation Index

- [Inventory Control Rules (BR-IC-XXX)](#inventory-control-rules-br-ic-xxx) - 20 rules
- [Accounts Payable Rules (BR-AP-XXX)](#accounts-payable-rules-br-ap-xxx) - 16 rules  
- [Accounts Receivable Rules (BR-AR-XXX)](#accounts-receivable-rules-br-ar-xxx) - 65 rules
- [Sales Orders Rules (BR-SO-XXX)](#sales-orders-rules-br-so-xxx) - 137 rules
- [Summary by Module](#summary-by-module)

---

## Inventory Control Rules (BR-IC-XXX)

### Item Management Rules

**BR-IC-001: Item Type Validation**
- Stock items must have valid warehouse assignments
- Non-stock items cannot have quantity on hand
- Service items cannot be received into inventory
- Kit items must have at least one component defined

**BR-IC-002: Unit of Measure Consistency**
- Primary UOM cannot be changed after transactions exist
- Conversion factors must maintain mathematical consistency
- Inter-class conversions require explicit approval

**BR-IC-003: Status Transition Rules**
- Active → Inactive: Allowed only when quantity_on_hand = 0
- Inactive → Discontinued: Requires management approval
- Discontinued → Active: Creates new revision with audit trail

### Serial/Lot Number Control Rules

**BR-IC-004: Serial Number Uniqueness**
- Serial numbers must be globally unique within item
- Format validation: `^[A-Z]{2}[0-9]{10}$` (configurable)
- Once assigned, serial numbers cannot be reused

**BR-IC-005: Lot Expiration Management**
- Expired lots automatically quarantined on expiration_date + buffer_days
- FEFO (First Expired First Out) picking when lot_controlled = true
- Retest intervals trigger quality hold status

**BR-IC-006: Traceability Requirements**
- All serial/lot controlled items maintain complete genealogy
- Forward tracing: raw_material → work_in_process → finished_good → customer
- Backward tracing: customer_complaint → finished_good → raw_material_batch

### Warehouse Operations Rules

**BR-IC-007: Bin Capacity Constraints**
- Validation: current_quantity + incoming_quantity <= bin_capacity
- Exception: allow_overflow = true AND overflow_percentage <= 10%

**BR-IC-008: Transfer Authorization**
- Inter-warehouse transfers > $10,000 require approval
- Cross-company transfers require inter-company agreement
- In-transit insurance required for transfers > $50,000

**BR-IC-009: Negative Inventory Prevention**
- Rule: quantity_on_hand - quantity_requested >= 0
- Exception: allow_negative_inventory = true AND user_role IN [inventory_manager, administrator]
- Timing: validation occurs at transaction_commit, not command_validation

### Physical Count Rules

**BR-IC-010: Count Freeze Logic**
- No transactions allowed during active count for counted bins
- Pending transactions queued until count completion
- Emergency overrides require dual authorization

**BR-IC-011: Variance Tolerances**
- A-items: tolerance = 0.5% OR $100, whichever is less
- B-items: tolerance = 2% OR $500, whichever is less
- C-items: tolerance = 5% OR $1000, whichever is less

**BR-IC-012: Recount Triggers**
- Automatic recount if variance > tolerance
- Blind recount by different counter required
- Third count by supervisor if variance persists

### Performance and System Rules

**BR-IC-013: Snapshot Management**
- Snapshot InventoryBalance aggregates monthly or after 1000 events
- Archive completed transfers after 90 days
- Partition cost layers by fiscal year

**BR-IC-014: Performance Optimization**
- Denormalize frequently accessed data in read models
- Cache ATP calculations with 5-minute TTL
- Pre-calculate ABC classifications daily

**BR-IC-015: Event Stream Lifecycle**
- Compress events older than 1 year
- Archive events older than 7 years
- Maintain separate streams per warehouse for scalability

### Security and Compliance Rules

**BR-IC-016: Approval Requirements**
- Inventory adjustments > $1,000 require manager approval
- Cost method changes require CFO approval
- Physical count variances > 5% require investigation

**BR-IC-017: Audit Trail Maintenance**
- All stock movements maintain complete audit trail
- User, timestamp, and reason code for every transaction
- Immutable event log for regulatory compliance

**BR-IC-018: Retention Policies**
- Transaction details: 7 years
- Lot/serial genealogy: Product lifetime + 2 years
- Physical count records: 3 years

### Migration and Compatibility Rules

**BR-IC-019: Migration Support**
- Support batch imports of historical transactions
- Maintain backward compatibility with existing item codes
- Gradual migration path from document-based to event-sourced

**BR-IC-020: Migration Validation**
- Opening balances loaded as initial StockReceived events
- Cost layers reconstructed from historical transactions
- Serial/lot numbers validated for uniqueness during import

---

## Accounts Payable Rules (BR-AP-XXX)

### Invoice Processing Rules

**BR-AP-001: Invoice Uniqueness**
- All invoices must have unique invoice number per vendor

**BR-AP-002: Invoice Date Validation**
- Invoice date cannot be future-dated
- Invoice date cannot be more than 90 days in the past

**BR-AP-003: Due Date Calculation**
- Due date must be calculated based on vendor payment terms

**BR-AP-004: Currency Validation**
- Currency must match vendor's approved currency list

### Three-Way Matching Rules

**BR-AP-005: Quantity Tolerance Rules**
- Quantity Variance: ±5% for standard items, ±2% for high-value items, 0% for controlled items

**BR-AP-006: Price Tolerance Rules**
- Price Variance: ±5% of PO price, with absolute maximum of $100

**BR-AP-007: Date Tolerance Rules**
- Date Variance: Invoice date within 7 days of receipt date

**BR-AP-008: Tax Tolerance Rules**
- Tax Variance: ±$0.01 rounding tolerance

**BR-AP-009: Variance Exception Processing**
- Variances outside tolerance trigger hold status
- Automatic routing based on variance type and amount
- Required approval levels based on variance severity
- Reason codes required for override approvals

### Approval and Authorization Rules

**BR-AP-010: Approval Delegation**
- Temporary delegation with start/end dates
- Approval limits can be inherited or reduced
- Delegation chains limited to 2 levels
- Audit trail of all delegated approvals

**BR-AP-011: GL Distribution Requirements**
- Support percentage-based splits across multiple accounts
- Support quantity-based splits for allocation
- Maintain audit trail of distribution changes
- Validate sum of distributions equals invoice total

### Payment Processing Rules

**BR-AP-012: Early Payment Discount Processing**
- Calculate NPV of discount vs. cost of capital
- Automatically select invoices with positive NPV
- Track discount captured vs. discount available metrics
- Generate exception report for missed discounts

**BR-AP-013: Payment Security Validations**
- Bank account validation via prenote or microdeposit
- OFAC/sanctions screening before payment execution
- Duplicate payment prevention checks
- Payment limit validation by method and vendor

### Performance and System Requirements

**BR-AP-014: System Capacity Requirements**
- Support 100,000+ invoices per month
- Process 50,000+ payments per month
- Handle 10,000+ active vendors
- Support 1,000+ concurrent users

**BR-AP-015: Performance Benchmarks**
- Invoice validation: < 2 seconds
- Payment processing: < 5 seconds
- Three-way matching: < 3 seconds
- Report generation: < 10 seconds for standard reports

**BR-AP-016: Event Processing Performance**
- Event persistence: < 100ms
- Event projection update: < 500ms
- Process manager reaction: < 1 second
- Read model query: < 200ms

---

## Accounts Receivable Rules (BR-AR-XXX)

### Customer Account Management Rules

**BR-AR-001: Credit Limit Validation**
- Credit limit validation against outstanding balances and open orders

**BR-AR-002: Customer Classification**
- Customer classification for pricing and discount tiers

**BR-AR-003: Territory Assignment**
- Territory and salesperson assignment rules

**BR-AR-004: Account Relationships**
- Parent-subsidiary account relationships

### Invoice Management Rules

**BR-AR-005: Invoice Numbering**
- Invoice numbering (system-generated or manual)

**BR-AR-006: Tax Calculation**
- Tax calculation based on shipping address

**BR-AR-007: Freight Calculations**
- Freight charge calculation by weight or fixed amount

**BR-AR-008: Discount Hierarchy**
- Discount application hierarchy

**BR-AR-009: Warehouse Support**
- Multi-warehouse support

**BR-AR-010: Inventory Integration**
- Inventory allocation and depletion

**BR-AR-011: Item Tracking**
- Serialized/lot-controlled item tracking

### Sales Returns Processing Rules

**BR-AR-012: Return Authorization**
- Return authorization validation

**BR-AR-013: Return Item Tracking**
- Serialized/lot/kit item return tracking

**BR-AR-014: Restocking Rules**
- Inventory restocking rules

**BR-AR-015: Credit Note Generation**
- Credit note generation

**BR-AR-016: Return Processing**
- Return bin assignment

### Payment Processing Rules

**BR-AR-017: Payment Method Validation**
- Payment method validation (cash, check, credit card, electronic)

**BR-AR-018: Auto-Application Logic**
- Auto-application logic based on invoice age

**BR-AR-019: Payment Discount Calculation**
- Prompt payment discount calculation

**BR-AR-020: Payment Priority**
- Payment to finance charge priority

**BR-AR-021: Multi-Currency Handling**
- Multi-currency exchange rate handling

**BR-AR-022: Payment Analysis**
- Average payment days calculation

### Finance Charges Rules

**BR-AR-023: Finance Charge Calculation**
- Charge calculation methods (percentage or fixed)

**BR-AR-024: Minimum Balance Requirements**
- Minimum balance thresholds

**BR-AR-025: Charge Period Restrictions**
- Charge period restrictions

**BR-AR-026: Compound Interest**
- Compound interest on outstanding charges

**BR-AR-027: Finance Charge Eligibility**
- Customer and pay code eligibility

### Credit Management Rules

**BR-AR-028: Refund Authorization**
- Refund authorization

**BR-AR-029: AP Integration**
- AP integration for check refunds

**BR-AR-030: Receipt Processing**
- Negative receipt generation

### Bank Deposit Management Rules

**BR-AR-031: Receipt Grouping**
- Receipt grouping by bank and date

**BR-AR-032: Deposit Documentation**
- Deposit slip generation

**BR-AR-033: Reconciliation Tracking**
- Bank reconciliation markers

### Multi-Currency Support Rules

**BR-AR-034: Exchange Rate Updates**
- Real-time rate updates
- Transaction-specific rate overrides

**BR-AR-035: Currency Gain/Loss**
- Gain/loss calculation on payment
- Revaluation processing

**BR-AR-036: Currency Matching**
- Bank account currency matching
- Customer currency preferences

**BR-AR-037: Multi-Currency Operations**
- Multi-currency price lists
- Foreign currency statements

### Data Validation Rules

**BR-AR-038: Customer Validation**
- Customer exists and is active

**BR-AR-039: Date Validation**
- Invoice date within open periods

**BR-AR-040: Terms Validation**
- Payment terms are valid

**BR-AR-041: Tax Code Validation**
- Tax codes are applicable

**BR-AR-042: Inventory Validation**
- Inventory availability for stock items

**BR-AR-043: Serial/Lot Validation**
- Serial/lot numbers are unique

### Payment Validation Rules

**BR-AR-044: Payment Amount Validation**
- Payment amount is positive

**BR-AR-045: Bank Account Currency**
- Bank account matches currency

**BR-AR-046: Credit Card Validation**
- Credit card is not expired

**BR-AR-047: Check Format Validation**
- Check number format is valid

**BR-AR-048: Receipt Date Validation**
- Receipt date is valid

### Credit Management Validation Rules

**BR-AR-049: Credit Limit Enforcement**
- Credit limit enforcement

**BR-AR-050: Past-Due Restrictions**
- Past-due balance restrictions

**BR-AR-051: Order Hold Management**
- Order hold triggers

**BR-AR-052: Collection Status**
- Collection status flags

### Period-End Processing Rules

**BR-AR-053: Period Posting Control**
- Prevent posting to closed periods

**BR-AR-054: Transaction Completeness**
- Ensure all transactions are posted

**BR-AR-055: GL Account Validation**
- Validate GL account mappings

**BR-AR-056: Period-End Reporting**
- Generate period-end reports

### Security and Access Control Rules

**BR-AR-057: Function Permissions**
- Function-level permissions

**BR-AR-058: Customer Restrictions**
- Customer-level restrictions

**BR-AR-059: Amount Thresholds**
- Amount thresholds

**BR-AR-060: Authorization Controls**
- Void/amendment authorization

### Audit Trail Rules

**BR-AR-061: Event Immutability**
- All events are immutable

**BR-AR-062: User Tracking**
- User tracking on all commands

**BR-AR-063: Timestamp Preservation**
- Timestamp preservation

**BR-AR-064: Amendment History**
- Amendment history

**BR-AR-065: Void Tracking**
- Void reason tracking

---

## Sales Orders Rules (BR-SO-XXX)

### Order Creation and Entry Rules

**BR-SO-001: Customer Validation**
- Orders require valid customer with active status

**BR-SO-002: Credit Check Requirements**
- Credit check must pass based on order value and customer limit

**BR-SO-003: Line Item Validation**
- All line items must have positive quantities

**BR-SO-004: Pricing Date Validation**
- Pricing date determines applicable price lists

**BR-SO-005: Address Requirements**
- Ship-to address required for physical items

### Quote-to-Order Conversion Rules

**BR-SO-006: Quote Approval Status**
- Only approved quotes can convert to orders

**BR-SO-007: Quote Expiration**
- Expired quotes require re-approval

**BR-SO-008: Price Change Notifications**
- Price changes trigger notification if variance exceeds threshold

**BR-SO-009: Discount Transfer**
- Quoted discounts transfer to order

### Order Entry Validation Rules

**BR-SO-010: Minimum Order Value**
- Minimum order value enforcement by customer type

**BR-SO-011: Line Item Limits**
- Maximum line items per order (configurable)

**BR-SO-012: Required Fields**
- Required fields validation based on order type

**BR-SO-013: Ship Date Validation**
- Date validation for requested ship dates

**BR-SO-014: Currency Restrictions**
- Currency restrictions by customer region

### Pricing Rules

**BR-SO-015: Price List Effectivity**
- Price list effectivity date validation

**BR-SO-016: Quantity Breaks**
- Quantity break application

**BR-SO-017: Discount Limitations**
- Discount stacking limitations

**BR-SO-018: Price Override Authorization**
- Manual price override authorization levels

**BR-SO-019: Price Variance Tolerance**
- Price variance tolerance thresholds

### Inventory Rules

**BR-SO-020: Safety Stock**
- Safety stock maintenance

**BR-SO-021: Allocation Priority**
- Allocation priority by customer class

**BR-SO-022: Kit Component Availability**
- Kit component availability requirements

**BR-SO-023: Substitution Approval**
- Substitution approval requirements

**BR-SO-024: Backorder Acceptance**
- Backorder acceptance criteria

### Credit Rules

**BR-SO-025: Credit Limit Enforcement**
- Credit limit enforcement

**BR-SO-026: Payment Term Restrictions**
- Payment term restrictions

**BR-SO-027: Hold Release Authority**
- Hold release authority levels

**BR-SO-028: Aging Thresholds**
- Aging threshold policies

**BR-SO-029: Credit Insurance**
- Credit insurance requirements

### Fulfillment Rules

**BR-SO-030: Partial Shipment Thresholds**
- Partial shipment minimum thresholds

**BR-SO-031: Carrier Selection**
- Carrier selection by service level

**BR-SO-032: Hazmat Restrictions**
- Hazmat shipping restrictions

**BR-SO-033: International Compliance**
- International trade compliance

**BR-SO-034: Drop Ship Requirements**
- Drop ship vendor requirements

### Audit and Tracking Rules

**BR-SO-035: Modification Logging**
- All order modifications logged with user and timestamp

**BR-SO-036: Price Override Justification**
- Price override justifications required

**BR-SO-037: Credit Override Tracking**
- Credit limit override tracking

**BR-SO-038: Cancellation Reason Codes**
- Cancellation reason codes mandatory

**BR-SO-039: Document Version History**
- Document version history maintained

### Shipping and Fulfillment Rules

**BR-SO-040: Payment Authorization for Shipping**
- Cannot ship without payment authorization if required

**BR-SO-041: Credit Limit at Shipping**
- Cannot exceed customer credit limit

**BR-SO-042: Shipping Address Validation**
- Must validate shipping address

**BR-SO-043: Location Restrictions**
- Cannot ship restricted items to certain locations

**BR-SO-044: Hazmat Special Handling**
- Special handling for hazmat

**BR-SO-045: Serial Number Requirements**
- Serialized items must have serial numbers

### Cancellation and Return Rules

**BR-SO-046: Same Day Cutoff**
- Same-day cancellation cutoff: 14:00:00

**BR-SO-047: In-Fulfillment Approval**
- In fulfillment requires approval for cancellation

**BR-SO-048: Shipped Order Protection**
- Shipped orders not cancellable

**BR-SO-049: Cancellation Time Limit**
- Maximum 30 days after order for cancellation

**BR-SO-050: Full Refund Period**
- Full refund period: 24 hours

**BR-SO-051: Restocking Fee**
- Restocking fee percentage: 15%

**BR-SO-052: Maximum Restocking Fee**
- Restocking fee maximum: $500.00

**BR-SO-053: Tax Refund**
- Tax refund required

**BR-SO-054: Payment Method for Returns**
- Original payment method required

### High-Value Order Rules

**BR-SO-055: High-Value Threshold**
- Value threshold: $5,000.00

**BR-SO-056: VIP Customer Approval**
- VIP customer approval required

**BR-SO-057: Partial Shipment Approval**
- Partially shipped approval required

**BR-SO-058: Bulk Cancellation Threshold**
- Bulk cancellation threshold: 10 orders

### Credit Verification Rules

**BR-SO-059: Credit Check Threshold**
- Required above: $10,000

**BR-SO-060: Soft Check Limit**
- Soft check limit: $50,000

**BR-SO-061: Hard Check Requirement**
- Hard check required above: $100,000

**BR-SO-062: Existing Customer Skip**
- Existing customer skip threshold: $5,000

**BR-SO-063: Credit Check Validity**
- Check validity days: 30

### Inventory Allocation Rules

**BR-SO-064: Overbooking Limit**
- Maximum overbooking percentage: 110% (10% more than available)

**BR-SO-065: Backorder Acceptance**
- Backorder acceptance required

**BR-SO-066: Partial Shipment Minimum**
- Partial shipment minimum: 50%

**BR-SO-067: Product Substitution**
- Substitute product approval required

### Quote Conversion Rules

**BR-SO-068: Primary Quote Requirement**
- Require primary quote

**BR-SO-069: Partial Conversion**
- Allow partial conversion

**BR-SO-070: Expired Quote Conversion**
- Expired quote conversion: false

**BR-SO-071: Credit Recheck Threshold**
- Credit recheck threshold: 30 days since last check

### Blanket Order Rules

**BR-SO-072: Contract Status Validation**
- Verify blanket order is active and not expired

**BR-SO-073: Date Validation**
- Ensure requested delivery date falls within contract period

**BR-SO-074: Quantity Validation**
- Confirm release quantity doesn't exceed remaining contracted quantity

**BR-SO-075: Credit Validation**
- Perform multi-stage credit limit checks with configurable enforcement

**BR-SO-076: Pricing Lock**
- Apply contracted pricing and discounts to released order

### Customer Management Rules

**BR-SO-077: Required Fields Check**
- Checks required fields by account group

**BR-SO-078: Credit Limit Reasonableness**
- Validates credit limit reasonableness

**BR-SO-079: Tax ID Format**
- Verifies tax ID format

**BR-SO-080: Address Deliverability**
- Ensures address deliverability

**BR-SO-081: Payment Term Compatibility**
- Checks payment term compatibility

**BR-SO-082: Insurance Coverage**
- Credit limits cannot exceed insurance coverage

**BR-SO-083: Tax-Exempt Status**
- Tax-exempt status requires valid certificate

**BR-SO-084: International Documentation**
- International customers require additional documentation

**BR-SO-085: Duplicate Detection**
- Duplicate customers detected by fuzzy matching

**BR-SO-086: Inactive Customer Orders**
- Inactive customers cannot place new orders

### Item Management Rules

**BR-SO-087: Safety Stock Requirements**
- Safety stock must exceed minimum quantity

**BR-SO-088: Lead Time Validation**
- Lead times validated against supplier performance

**BR-SO-089: Lot Control Tracking**
- Lot-controlled items require expiration tracking

**BR-SO-090: Serial Tracking**
- Serialized items enforce one-to-one tracking

**BR-SO-091: Kit Component Validation**
- Kit components must be valid items

### Order Processing Rules

**BR-SO-092: Credit Limit Enforcement**
- Orders cannot exceed customer credit limit without approval

**BR-SO-093: Minimum Order Quantities**
- Minimum order quantities enforced

**BR-SO-094: Shipping Date Validation**
- Shipping dates validated against calendars

**BR-SO-095: Tax Calculation Verification**
- Tax calculations verified against nexus rules

**BR-SO-096: Discount Authorization**
- Discounts require authorization above thresholds

### General Ledger Integration Rules

**BR-SO-097: Accounting Balance**
- Debits must equal credits

**BR-SO-098: Posting Period Validation**
- Posting periods must be open

**BR-SO-099: Foreign Currency Requirements**
- Foreign currency requires exchange rates

**BR-SO-100: Intercompany Balance**
- Intercompany transactions balance

**BR-SO-101: Supporting Documents**
- Supporting documents required for audit

### Workflow Validation Rules

**BR-SO-102: Credit Check Workflow**
- Credit check required when order_value > $5,000

**BR-SO-103: Manager Approval Workflow**
- Manager approval required when discount > 20%

**BR-SO-104: Inventory Check Workflow**
- Inventory check required when immediate_shipment = true

**BR-SO-105: Address Validation Workflow**
- Address validation required when international = true

### Tax Configuration Rules

**BR-SO-106: Tax Rate Validity**
- Tax rates must have valid effective dates with no gaps in coverage

### Banking Rules

**BR-SO-107: GL Account Assignment**
- Bank accounts must have valid GL account assignments

**BR-SO-108: Currency Matching**
- Currency must match for multi-currency transactions

### Data Access Rules

**BR-SO-109: Permission-Based Filtering**
- Filters must respect data access permissions

### Customer Configuration Rules

**BR-SO-110: Billing Address Requirement**
- Each customer must have at least one billing address

**BR-SO-111: Credit Increase Expiration**
- Temporary credit increases require expiration date

**BR-SO-112: Credit Hold Authorization**
- Credit hold releases require authorization

### Inventory Configuration Rules

**BR-SO-113: Lot Control Setup**
- Lot-controlled items require lot tracking setup

**BR-SO-114: Storage Requirements**
- Bin assignments respect item storage requirements

**BR-SO-115: Hazmat Location Requirements**
- Hazmat items require specialized locations

**BR-SO-116: Expiration Validation**
- Expiration date validation for perishables

**BR-SO-117: Serial Number Requirements**
- Serial numbers required at specific transaction points

### Pricing Configuration Rules

**BR-SO-118: Promotional Price Validation**
- Promotional prices require valid dates

**BR-SO-119: Minimum Price Validation**
- Minimum price validation enforced

**BR-SO-120: Price Change Authorization**
- Price changes require authorization based on impact

### Salesperson Management Rules

**BR-SO-121: Salesperson ID Uniqueness**
- Salesperson ID must be unique

**BR-SO-122: Commission Rate Validation**
- Commission rate must be between 0 and 100

**BR-SO-123: Territory Assignment**
- At least one territory must be assigned

**BR-SO-124: Manager Reference Validation**
- Manager ID must reference existing salesperson if provided

**BR-SO-125: Active Salesperson Requirement**
- Active salesperson required for new orders

**BR-SO-126: Commission Change Restrictions**
- Commission changes cannot be retroactive

**BR-SO-127: Territory Overlap Prevention**
- Territory assignments must not overlap

### Territory Management Rules

**BR-SO-128: Territory Code Uniqueness**
- Territory codes must be unique

**BR-SO-129: Geographic Boundary Validation**
- Geographic boundaries must not overlap with same type

**BR-SO-130: Parent Territory Validation**
- Parent territory must exist if specified

### Customer Pricing Rules

**BR-SO-131: Entity Validation**
- Customer and product must exist

**BR-SO-132: Custom Pricing Authorization**
- Custom pricing requires approval if below minimum margin

### Promotional Pricing Rules

**BR-SO-133: Date Range Validation**
- Date ranges must not overlap for same scope

**BR-SO-134: Discount Limits**
- Discount cannot exceed maximum allowed percentage

**BR-SO-135: Discount Stacking Approval**
- Approval required for stacking

### Template Management Rules

**BR-SO-136: Template Code Uniqueness**
- Template codes must be unique

**BR-SO-137: Activity Code Uniqueness**
- Activity codes must be unique

---

## Summary by Module

| Module | Rule Count | Rule Range |
|--------|-----------|------------|
| **Inventory Control** | 20 | BR-IC-001 to BR-IC-020 |
| **Accounts Payable** | 16 | BR-AP-001 to BR-AP-016 |
| **Accounts Receivable** | 65 | BR-AR-001 to BR-AR-065 |
| **Sales Orders** | 137 | BR-SO-001 to BR-SO-137 |
| **Total** | **238** | All Modules |

### Implementation Notes

1. **Rule Numbering**: Each module uses its own sequential numbering system starting from 001
2. **Cross-Module Dependencies**: Some rules reference or depend on rules from other modules
3. **Configuration**: Many rules include configurable thresholds and parameters
4. **Authorization**: Rules requiring approval specify the appropriate authorization levels
5. **Audit Trail**: All rule violations and overrides must be logged for compliance

### Development Guidelines

- Always validate business rules at the appropriate layer (command validation, aggregate invariants, etc.)
- Include rule numbers in error messages and logs for easy tracking
- Write comprehensive tests covering both rule enforcement and valid override scenarios
- Update this document when adding, modifying, or deprecating business rules
- Consider performance implications when implementing complex validation rules

This reference guide serves as the single source of truth for all business rules in the Accountex ERP system. Keep it updated as the system evolves and new rules are added.