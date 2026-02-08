# Agentic Enrichment

Traditional databases are passive. They store what you give them. If you ask a question and the data isn't there, you get an empty result. 

Samyama introduces **Agentic Enrichment**—a paradigm shift where the database becomes an active participant in building its own knowledge.

## From RAG to GAK

We are all familiar with **Retrieval-Augmented Generation (RAG)**: using a database to help an LLM. 
Samyama implements **Generation-Augmented Knowledge (GAK)**: using an LLM to help build the database.

## The Autonomous Enrichment Loop

Samyama can be configured with **Enrichment Policies**. When a new node is created or a specific property is queried, an autonomous agent can "wake up" to fill in the gaps.

### Example: The Research Assistant
Imagine you are building a medical knowledge graph. You create a node for a new drug, `Semaglutide`.

**The Passive Way**: You manually search PubMed, find papers, and insert them.
**The Samyama Way**: 
1.  You create the `Drug` node.
2.  An **Event Trigger** fires an Enrichment Agent.
3.  The Agent uses a **Web Search Tool** to find recent clinical trials.
4.  The Agent parses the results into JSON.
5.  The database automatically executes `CREATE` commands to link the new papers to the `Drug` node.

## Just-In-Time (JIT) Knowledge Graphs

This enables what we call a **JIT Knowledge Graph**. The graph doesn't need to be complete on day one. It grows and "heals" itself based on user interaction. 

If a user asks: *"How does the current Fed interest rate impact my mortgage?"* and the `Fed Rate` node is missing, the database can fetch the live rate, create the node, and then answer the question.

By integrating LLMs directly into the write pipeline, Samyama transforms from a simple storage engine into a dynamic, self-evolving brain.
