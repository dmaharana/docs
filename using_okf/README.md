For GitHub Copilot in VS Code
You can use the `.github/instructions.md` feature (or workspace rules) to force Copilot to respect and read your OKF directory.

- Create a .github/instructions.md file in your repository.

- Tell Copilot how to read your bundle using a prompt like this:

```
# AI Agent Instructions
You have access to a curated Open Knowledge Format (OKF) knowledge base located in the `/docs` directory. 

When answering questions about our business logic, architecture, or schemas:
1. Always look for the closest OKF Markdown files in `/docs` first.
2. Read the YAML front matter to understand the `type` and metadata relationships.
3. Follow the internal relative Markdown links (`[text](relative-path.md)`) to build context.
4. Prioritize the deterministic information inside these files over your general training data.
```
