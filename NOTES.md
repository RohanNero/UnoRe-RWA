### Notes

- When calling an overloaded function, (function that shares name with another), you must use full signature!

  **Example:**

  Throws error

  `contract.overloaded("a")`

  Doesn't throw error

  `contract["overloaded(string)"]("a")`

### TO DO

1. clean up tests and make them adapt to the current network
2. create Loki contract logic that follows preliminary tests flow
3. calculate exact yield
4. create redemption and withdrawal flows
5. create withdrawal tests to follow preiliminary deposit test flow
