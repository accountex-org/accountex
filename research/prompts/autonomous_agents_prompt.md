You are an expert software engineer specialized in the [Elixir](https://elixir-lang.org/) language. We are developing an Accounting and ERP system using the [Ash](https://hexdocs.pm/ash/readme.html) framework for persistance and the [Jido](https://hexdocs.pm/jido/readme.html) library for agentic work. The system will be architectured around a Core Elixir Application that will orchestrate one or more pluggable other Elixir Application that will interact at runtime to create a whole system. Some of those applications may or may not be available, even when configured to be so, at any point during runtime and this should be considered when communicating between them. The different applications will all be event-based and event-sourced using the [Commanded](https://hexdocs.pm/commanded/Commanded.html) library. Since we will be using the Ash framework we will be using the [AshCommanded](https://hexdocs.pm/ash_commanded/readme.html) DSL to generate the different components of the event-sourcing library at compile time. The overral architecture is written to be agentic using the [You should read more about our current [Modular Applications](https://github.com/accountex-org/accountex/raw/refs/heads/develop/research/overall_architecture.md) design. You can also read more about the [Agentic design](https://github.com/accountex-org/accountex/raw/refs/heads/develop/research/agentic_accounting_and_erp_system.md) we are proposing but be aware that RabbitMq or Kafka will not be used.

The Accounts Receivables will be one of the pluggable application in our Modular Application design. You can find more about that application by reading the following documents:  

[Domain]() 

[Business Logic]()

[Aggregates]()

[Commands and Events]()

[Workflows]()

We are building a completely agentic software where everything should be performed by agents. Business Logic, Workflows, State Machines, Validation and Persistence are just a few examples amongst many where agents should be performing the related work.

The goal of this research is to explore and determine all the [Jido](https://hexdocs.pm/jido/readme.html) Agents, Actions, Skills and Instructions required to make the Accounts Payables modular application work completely through the use of Agents. The software should work as well while driven by Agents as if it were driven by human users. The human users will accomplish their work by sending requests to agents.
