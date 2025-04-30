# 🌾 YieldLock

**YieldLock** is a parametric crop insurance smart contract built on the Stacks blockchain using Clarity. It enables decentralized, automatic payouts to farmers based on predefined weather conditions such as drought, excessive rainfall, or frost. Payouts are triggered by verifiable data submitted by authorized weather oracles—no manual claims process required.

## 🚀 Key Features

- **Automated Payouts:** Triggered by weather data crossing predefined thresholds (rainfall, temperature).
- **Decentralized Oracles:** Weather data is submitted and verified by multiple authorized oracle providers.
- **Risk Pools:** Crop-type-specific insurance pools with reserve management and protocol fees.
- **Policy Management:** Farmers can create, evaluate, or cancel policies and receive time-based refunds if canceled early.
- **Climate Resilience:** Designed to protect yield and livelihood in the face of increasing climate variability.

---

## 📘 How It Works

1. **Policy Creation:**
   - A farmer creates a policy by providing:
     - Location, crop type, coverage & premium amount
     - Weather trigger thresholds
     - Coverage duration and oracle provider
   - Premium is split between the protocol and the crop-specific risk pool.

2. **Weather Data Submission:**
   - Authorized oracles submit weather data to the contract.
   - Data is optionally verified by a second oracle.

3. **Trigger Evaluation:**
   - Weather data is matched with active policies.
   - If data breaches any threshold (drought, excess rain, frost), a payout is triggered automatically.

4. **Payout Execution:**
   - Insurance payout is sent directly to the policyholder.
   - Risk pool balances and policy status are updated.

5. **Manual Overrides:**
   - Policyholders or oracles can manually trigger evaluation if needed.

---

## 📂 Smart Contract Structure

- `insurance-policies` – Stores all active and historical insurance policies.
- `weather-data` – Contains submitted and verified weather reports by oracles.
- `authorized-oracles` – Manages a list of oracles and their verification status.
- `risk-pools` – Tracks pooled funds, payouts, and balances for each crop type.
- `protocol-fee-recipient` – Receives a portion of the premium for protocol sustainability.

---

## 🛠 Functions

### 🔐 Public Functions

- `create-policy` – Create a new crop insurance policy.
- `submit-weather-data` – Oracle submits weather info for a location.
- `register-oracle` – Register a new weather oracle.
- `verify-weather-data` – Confirm weather data from another oracle.
- `cancel-policy` – Cancel a policy and receive a prorated refund.
- `evaluate-policy` – Manually trigger evaluation of a specific policy.

### 📊 Read-Only Functions

- `get-policy` – View details of a specific policy.
- `get-weather-data` – Retrieve weather data for a location and timestamp.
- `get-risk-pool` – Check the financials of a crop-specific risk pool.
- `check-oracle-authorization` – Verify if an oracle is authorized.

---

## ✅ Requirements

- Stacks blockchain environment
- Clarity 2.0 compatible tools (e.g., Clarinet for local development)
- Oracle providers for weather data feeds

---

## 🔒 Security Notes

- Oracle registration is simplified; in a production environment, governance or multi-sig approval should be used.
- Weather data is verified by a second oracle for basic redundancy; more robust consensus methods are recommended for high-value deployments.

---

## 💡 Use Cases

- **Drought Insurance:** Farmers receive funds when rainfall falls below critical thresholds.
- **Flood Protection:** Coverage for excessive rainfall events that damage crops.
- **Frost Coverage:** Shield against unseasonal cold snaps.

---

## 📬 Contact

Questions or ideas? Reach out to contribute or collaborate!  
Smart contract name: `YieldLock`  
Contract language: Clarity (for Stacks blockchain)