# Implementing Business Rules in an Event-Sourced Elixir ERP

## Context: Business Rules in Event Sourcing (Elixir + Commanded)

In an event-sourced ERP system using Elixir (with the Commanded
library), critical business rules (e.g. credit limit checks, customer
pricing tiers, territory assignment, parent-subsidiary constraints) must
**always be enforced**. These rules ensure data integrity and consistent
decisions across the domain. Some rules are purely **invariant checks**
(like preventing sales over the credit limit), while others **derive or
trigger actions** (assigning a salesperson, sending alerts, updating
related accounts). Managing **hundreds of such rules** calls for a
structured approach to avoid scattering logic across aggregates. Key
requirements include:

-   **Hard-Coded but Easily Defined**: Rules will be defined in code,
    yet should be simple to write and read (possibly via a DSL).\
-   **Trigger Side-Effects**: Certain rules invoke follow-up processes
    or events (e.g. flagging an account, sending a notification).\
-   **Centralized Management**: A single source of truth for rules
    (rather than duplicated across modules) to simplify updates and
    ensure consistency.\
-   **Evolving with Versioning**: Business logic can change (e.g. new
    credit policies). The system should accommodate rule changes over
    time, ideally without breaking historical event processing.

## Approaches to Representing Business Rules in Elixir

### 1. **Inline Logic in Aggregates vs. External Rule Modules**

The simplest approach is to encode checks directly in your Commanded
aggregates or command handlers (e.g., in the aggregate's `execute`
function, reject a `PlaceOrder` command if the credit limit would be
exceeded). This guarantees rules run *synchronously* before events are
recorded. However, with many rules, **scattering logic** throughout
aggregates becomes hard to maintain. Instead, consider **centralizing
rules** in a dedicated module or service that aggregates can call. For
example, an `ERP.Rules` module could expose functions to validate or
apply all relevant rules for a given context (order placement, customer
update, etc.). This keeps rule definitions in one place.

### 2. **Domain-Specific Language (DSL) for Rules with Spark**

Leveraging a DSL can make rule definitions more declarative and
manageable. The [Spark
library](https://hexdocs.pm/spark/get-started-with-spark.html) is
designed for building DSLs in Elixir, as seen in the Ash framework.
Using Spark, you can define a **rules DSL** to express conditions and
actions in a readable form without writing low-level macros. For
instance, you might create a DSL like:

``` elixir
defmodule MyApp.Rules do
  use MyRulesDSL  # built with Spark

  rule "CreditLimitCheck" do
    condition fn order, customer ->
      customer.credit_limit >= customer.outstanding + order.amount
    end
    action :prevent, "Credit limit exceeded"
  end

  rule "AssignSalesperson" do
    condition fn customer -> customer.salesperson_id == nil end
    action fn customer -> assign_default_salesperson(customer) end
  end

  # ...other rules...
end
```

Under the hood, Spark will help turn such DSL definitions into data
structures and functions. It provides *extensibility* (others can add
new rules or extensions), inline documentation, and tooling support out
of the box. The DSL approach makes rules **easy to read and update**,
and **centrally located** (all rules could live in one or a few
modules). This satisfies the need for hard-coded but easily definable
rules.

### 3. **Using a Rules Engine Library** (Pattern Matching & Rete Algorithms)

For extremely complex rule interactions, a dedicated **rules engine**
could be considered. There are Elixir libraries (in varying stages of
maturity) for rule engines. For example, *Ruler* is an Elixir library
introduced by James MacAulay that lets you define rules with pattern
matching and uses the **Rete algorithm** under the hood for efficiency.
Other efforts include a port of EasyRules (*rules_engine* by Bob
Sollish) and *Wongi Engine* (a forward-chaining Rete-based engine).
These engines allow you to input a set of facts (e.g. the current state
as facts) and then automatically fire all matching rules, which can be
powerful if rules *cascade or interact*.

**Pros**: A rule engine can optimize evaluation when there are *many
rules* by avoiding naive brute-force checks for each rule. It also
separates rule logic from imperative code. Some engines even allow
non-developers to adjust rules (e.g. via JSON or UI), though that might
not be needed if rules remain in code.

**Cons**: Introducing a full rule engine adds complexity. As Martin
Fowler warns, large rule systems with complex chaining logic can become
*hard to reason about*. If your rules are relatively straightforward
(even if numerous) and mostly operate independently, a simpler DSL or
function-based approach might be preferable. In many cases, a "naive"
implementation (iterating through rules with boolean conditions) is
sufficient and easier to maintain.

**Recommendation**: Use a rules engine library only if you anticipate a
lot of interdependent rules or need the advanced features of
forward-chaining/inference. Otherwise, building a lightweight rule
evaluator (possibly via Spark DSL) will keep your solution simpler.

## Integrating Rules into the Event-Sourced Architecture

### 1. **Enforcing Invariants at Command Execution**

In event sourcing (CQRS/ES), the **aggregate** (domain model) is
responsible for validating business rules before emitting events. For
example, a `OrderAggregate` should refuse a `PlaceOrder` command if the
credit rule fails (e.g., throw an error or return an `:error` tuple).
With a centralized rules module or DSL, your aggregate's logic can call
something like `Rules.validate(:place_order, order, customer_state)`
which checks all relevant rules (credit limit, customer status, etc.)
and returns any violations. This keeps the aggregate code clean while
still applying *all mandatory rules*. By doing this in the command
handling, you ensure invalid transactions never even produce an event.
(This approach aligns with the idea that the **domain model should hold
and apply the rules**, even if the rule definitions are abstracted out.)

### 2. **Triggering Side-Effects via Events and Process Managers**

For rules that cause follow-up actions (side effects), leverage the
event-driven nature of Commanded. Instead of performing side effects
immediately in the aggregate (which is discouraged since aggregates
should be pure functions of state), emit a **domain event** and handle
it elsewhere. There are two patterns to consider:

-   **Domain Events for Policy Actions**: If a rule is triggered, emit a
    specific event representing that outcome. For instance, if an order
    exceeds credit, the aggregate might emit an
    `OrderRejectedDueToCreditLimit` event (instead of the normal
    `OrderPlaced`). If a new customer is created without a salesperson,
    emit a `SalespersonAssignmentNeeded` event. These events capture the
    rule outcome explicitly. Then, you can have an Event Handler or
    Process Manager listening to these events to perform the
    side-effects (like sending a notification, creating a task for a
    manager, etc.). This way, the *decision* is recorded in the event
    log and the side effect can be carried out asynchronously, keeping
    the aggregate logic side-effect free.

-   **Process Managers / Sagas**: Alternatively, use a Commanded
    **Process Manager** that subscribes to relevant events and runs the
    rule logic as part of a long-running process. For example, a process
    manager could listen for any `OrderPlaced` events, then check the
    customer's credit balance from a read model and if it violates
    policy, dispatch a compensating command (`CancelOrder` or
    `PlaceCustomerOnHold`). This is more complex, but sometimes useful
    if the rule spans multiple aggregates or needs to orchestrate
    several actions. Essentially, the process manager becomes a
    **central enforcer** for certain rules, which matches the idea of
    centralized rule management.

Which approach to choose depends on whether the rule's action should be
immediate and part of the same transaction or can be eventual.
**Critical constraints** (like "do not allow the event at all") should
be handled in the aggregate synchronously. **Follow-up actions**
(notifications, cascading changes) can be handled by events and process
managers after the fact. This aligns well with CQRS: the write side
enforces invariants, while the read side or reactive processes handle
side effects.

### 3. **Central Repository of Rules**

To keep management simple, gather your rules in a central place. If
using a DSL (Spark), you might have a `MyApp.Rules` module or even
separate modules per context (e.g. `AR.Rules` for Accounts Receivable
related rules). All these modules could use the same DSL, and you can
document them in one section. Spark will also allow generating
documentation for your custom DSL, meaning each rule can be documented
(name, description, etc.) and you can ensure they are well understood.
This central repository makes it clear for developers (and business
analysts) what all the enforced rules are. It also simplifies
**testing** -- you can write tests that load all rules and simulate
scenarios to ensure the correct ones fire.

## Handling Evolving Rules and Versioning

Business rules often change (e.g. policy updates, new regulations,
different formulas). In an event-sourced system, this is tricky because
past events were applied under old rules. Here are strategies to manage
evolution:

-   **Code Versioning & Deployment**: The simplest method is to treat
    rule changes as code changes. You update the rule definitions (or
    DSL) and deploy a new version of the application. New
    commands/events will now use the new rules. Historical events remain
    as they were -- you typically *don't retroactively re-evaluate old
    events* if the rules changed only going forward. This is acceptable
    in many domains (e.g., credit policy changes apply to new orders,
    not past ones).

-   **Temporal Logic in Domain**: If a rule truly needs to apply
    differently before/after a certain date or version, include that
    logic in the rule condition. Martin Fowler suggests that if logic
    changes over time (e.g. "charge \$10 before Nov 18 and \$15 after"),
    the domain model can incorporate that **temporal condition** or use
    a strategy pattern keyed by date. In practice, your rule could check
    the current date or an **effective version** to decide which branch
    of logic to use. This can get messy if overused, so limit such
    temporal branching to cases where it's absolutely necessary.

-   **Versioned Rule Sets**: In a more advanced setup, you might
    maintain multiple sets of rules identified by a version or date. For
    example, the rules DSL could support `@version` tags. During event
    replay or auditing, the system could apply the rule logic
    corresponding to the historical version. Fowler describes an
    approach of looking up a rule set by date, e.g.,
    `chargingRules.get(date).process(event)`. This approach ensures
    correctness if you need to *recompute* outcomes as they were in the
    past versus how they would be under new rules. However, implementing
    this is complex and usually unnecessary unless you have a
    requirement for **bi-temporal audit** or retroactive adjustments.
    Most systems avoid this complexity -- *"don't go down this path
    unless you really need to"*.

-   **Treat Rule Changes as Events** (Advanced): In some architectures,
    changes to business rules themselves can be captured as special
    events (a kind of meta-event). For instance, an event like
    `CreditPolicyUpdated(new_threshold)` could be recorded. The system
    could use the event log to reconstruct which rules were active at
    any given time. This is aligned with an **Adaptive Object Model** or
    even embedding scripts for rules, but it introduces significant
    complexity in an event-sourced system. If pursuing this, ensure such
    rule-change events are applied in a controlled way (e.g., toggling a
    strategy module) and under configuration management. In most cases,
    managing rule changes through code and configuration is simpler.

## Summary of Best Practices

-   **Use a DSL or Dedicated Module** for business rules to keep them
    centralized and human-readable. The Spark library can greatly ease
    DSL creation for this purpose. This meets the need for hard-coded
    but easily definable rules.\
-   **Enforce critical rules within aggregates/commands** to prevent
    invalid events. This ensures the **integrity of your event stream**
    (no events that violate invariant rules).\
-   **Leverage Event-Driven Reactions** for rules that trigger follow-up
    actions. Model these as separate events or use process managers to
    handle side effects asynchronously, keeping the domain logic pure.
    This plays to the strengths of CQRS/ES and ensures side-effects are
    not missed (since they're driven by recorded events).\
-   **Keep rule logic maintainable**. Avoid an overly complex,
    prolog-style rule engine unless necessary. Simple condition-action
    pairs, iterated in a predictable way, are often sufficient and
    easier to reason about. Complex chaining can be a *"smell"* if it
    makes the system hard to understand. When using a lot of rules,
    document and test them well.\
-   **Plan for evolution carefully**. Most rule changes can be handled
    by updating the code/DSL and moving forward. If historical
    correctness under old rules is required (for audits or
    recalculations), consider versioning your rules or embedding date
    logic. Otherwise, keep things simple and treat rule changes as part
    of normal software iteration (with thorough testing when a rule
    changes).

By following these practices, you create a robust rules subsystem within
your Elixir event-sourced application. All rules live in one place, are
applied consistently at the right time, and can evolve as your business
requirements change. This approach ensures your ERP's complex logic
(credit checks, classifications, assignments, relationships, etc.)
remains **intelligible, testable, and adaptable** over the long term.

