# PowerShell Engineering Standards, Style Guide, & Best Practices

This document establishes the official technical proficiencies, algorithmic constraints, and design patterns for building high-performance, maintainable, and production-grade automation utilities. It synthesizes advanced memory optimization principles with the consensus established by the *PoshCode Unofficial PowerShell Best Practices and Style Guide*.



## 1. Core Architecture & Memory Management

PowerShell systems operating at enterprise scale must move away from default, monolithic collection patterns. All codebases must adhere to strict performance baselines regarding data allocation.

### Collection Strategy & Decision Matrix

| Operation Type | Collection Mechanism | .NET Class Mapping | Time Complexity | Legacy Anti-Pattern / Prohibited Code |
| :--- | :--- | :--- | :--- | :--- |
| **Fixed Boundary Storage** | Native Array | `System.Array` / `[T[]]` | $O(N)$ (for resize) | Appending elements via `+=` |
| **Dynamic Type-Safe Lists** | Generic List | `System.Collections.Generic.List[T]` | $O(1)$ (amortized) | `System.Collections.ArrayList` |
| **Unique Constraints / Dedup** | Hash Set | `System.Collections.Generic.HashSet[T]` | $O(1)$ lookup/add | Piping array to `Select-Object -Unique` |
| **Constant-Time KV Lookups** | Dictionary | `System.Collections.Generic.Dictionary[TKey,TValue]` | $O(1)$ lookup | Untyped hashtable manipulation |
| **Pipeline Batching (FIFO)** | Generic Queue | `System.Collections.Generic.Queue[T]` | $O(1)$ add/remove | Multi-pass array windowing loops |
| **State Reversal / Undo (LIFO)**| Generic Stack | `System.Collections.Generic.Stack[T]` | $O(1)$ push/pop | Direct recursive index parsing |

### Memory Layer Engineering Requirements

* **REQ-MEM-01: Mitigation of the Array Allocation Trap**
  Scripts processing data collections tracking higher than 100 elements **must not** use the array addition assignment operator (`+=`). This operator forces immediate full array cloning and reallocation in memory, tanking system performance as indices compound. Use direct loop pipeline assignment or type-safe, in-memory collection builders.
```powershell
  # APPROVED PATTERN A: Direct loop assignment
  $ProcessedData = for ($i = 0; $i -lt 10000; $i++) { [PSCustomObject]@{ Index = $i } }

  # APPROVED PATTERN B: In-memory dynamic list collection
  using namespace System.Collections.Generic
  $LogBuffer = [List[string]]::new()
  $LogBuffer.Add("Transaction entry logs...")

```

* **REQ-MEM-02: Total Deprecation of ArrayLists**
The use of `System.Collections.ArrayList` is strictly banned in new module developments. Because it functions on an untyped `[object]` boundary layer, it introduces heavy runtime boxing/unboxing overhead. Interop operations must migrate to type-safe `System.Collections.Generic.List[T]` allocations.
* **REQ-MEM-03: Ultra-Fast Deduplication and Set Logic**
Datasets requiring distinct uniqueness evaluations must utilize underlying mathematical set engines rather than filtering commands downstream.

```powershell
  # APPROVED: O(1) deduplication that silences duplicates seamlessly 
  using namespace System.Collections.Generic
  $UniqueSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($Line in $RawData) { [void]$UniqueSet.Add($Line) }

```

* **REQ-MEM-04: Non-Sequential Pipeline Indexing**
Querying deeply nested arrays iteratively via sequential checks (`Where-Object`) is prohibited inside performance-critical lookup iterations. Engineers must build an indexed memory index map beforehand.

```powershell
  # APPROVED: Conversion to constant-time O(1) pointer indexes
  $ActiveUserIndex = $ADUsersArray | Group-Object -Property SamAccountName -AsHashTable -AsString
  $Target = $ActiveUserIndex['jdoe']

```

---

## 2. PoshCode Style & Clean Code Conventions

To maximize readability across distributed infrastructure engineering groups, script configurations must comply with the community rules set forth by the PoshCode Style Guide.

### Command Structure & Naming Mechanics

* **REQ-STY-01: Prohibited Alias Consumption**
Aliases (e.g., `dir`, `ls`, `gci`, `gps`, `select`, `where`) are strictly prohibited inside production-grade manifest scripts, module packages, and shared configuration tools. Script authors must always write the full, explicit `Verb-Noun` command definition to maintain readable and stable syntax.

```powershell
  # PROHIBITED
  gps | ? { $_.Name -eq 'Explorer' } | select -f 1

  # APPROVED
  Get-Process | Where-Object { $_.Name -eq 'Explorer' } | Select-Object -First 1

```

* **REQ-STY-02: Explicit Parameter Declarations**
Avoid utilizing positional arguments when calling intricate cmdlet blocks. Always declare target parameters explicitly to prevent runtime breakage if parameter sets are modified by underlying module package upgrades.

```powershell
  # PROHIBITED
  Get-Content 'C:\Logs\App.log'

  # APPROVED
  Get-Content -Path 'C:\Logs\App.log'

```

* **REQ-STY-03: Casing Standards**
Maintain consistency across variable names, syntax targets, and parameters:
* **PascalCase:** Reserved for command names (`Get-Command`), parameters (`-Identity`), public property accessors, and environment parameters.
* **lowercase:** Reserved entirely for structural language keywords (`if`, `foreach`, `switch`, `while`, `try`, `catch`).



### Path Handling and Environment Safety

* **REQ-STY-04: Mitigation of Relative Paths in Underlying Framework Interops**
Using raw relative pathways (`.\RelativeFile.json` or `..\Config.ini`) when interoperating with structural `.NET` classes is strictly banned. `.NET` methods resolve paths against `[Environment]::CurrentDirectory`, which does not synchronize dynamically with the active PowerShell working context (`$PWD`).
All paths inside shared utilities must base their root pointer paths definitively via `$PSScriptRoot`. The tilde shorthand symbol (`~`) to target user directories is prohibited due to provider instability.

```powershell
  # PROHIBITED
  [System.IO.File]::ReadAllText(".\settings.json")

  # APPROVED
  $SecurePath = Join-Path -Path $PSScriptRoot -ChildPath 'settings.json'
  Get-Content -Path $SecurePath

```

---

## 3. Tool Building & Robust Error Management

Scripts must act like standard system cmdlets, respecting normal error mechanisms and output pipelines.

* **REQ-TL-01: Mandatory Advanced Function Wrappers**
All scripts intended for sharing must leverage advanced function blocks via the `[CmdletBinding()]` decorator. Raw, positional parameter extraction blocks (`$args`) are forbidden. Parameters must enforce strict definitions, typing, and input constraints.

```powershell
  function Get-SecureAsset {
      [CmdletBinding()]
      param (
          [Parameter(Mandatory = $true)]
          [ValidateNotNullOrEmpty()]
          [string]$AssetIdentifier
      )
      process { ... }
  }

```

* **REQ-TL-02: Prevention of Output Formatting Disruptions**
Functions must pass raw, unformatted objects through the output pipeline. Hardcoding structural user interface output modifiers (`Format-Table`, `Format-List`, `Out-String`) inside a utility's functional tracking scope is banned. UI adjustments must occur solely at the final execution context layer.
* **REQ-TL-03: Bulletproof Exception Traps**
Critical state changes or external interface connections must be wrapped in `try { ... } catch { ... }` exception blocks. Non-terminating native faults must be escalated to formal terminating errors using the `-ErrorAction Stop` parameter whenever critical automation state execution safety relies on them.

---

## 4. Architectural Guardrails

* **Target Script Engine Compliance:** Scripts and module packages must target a minimum execution runtime base of **PowerShell 7.5+** to leverage modern engine compiler memory layout improvements.
* **Concurrency Processing Guardrails:** When operating concurrent processing instances via `-Parallel` parameters, developers must isolate standard shared variables and swap dynamic collection allocations to their thread-safe structural twins under `System.Collections.Concurrent`.
