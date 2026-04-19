# Florida Articles of Organization — Nomad Labs LLC
## Single-Member LLC Filing Guide

**Member:** Emilio John Alecci
**Address:** 5353 Gulf Blvd APT A304, St. Pete Beach, FL 33706

---

## How to file

1. Go to **https://dos.fl.gov/sunbiz/start-business/efile/fl-llc/**
2. Select **"File New Florida Limited Liability Company"**
3. Enter the information below
4. Filing fee: **$125** ($100 for Articles + $25 for Registered Agent designation)
5. Optional expedited processing: **+$30** (not needed — standard is ~5-7 business days)
6. Pay by credit card

Save the confirmation email — it contains your Document Number (format: L26000XXXXXX).

---

## Before you file: Name availability check

Go to https://search.sunbiz.org/Inquiry/CorporationSearch/ByName and search **"Nomad Labs"**.

Confirm no identical or deceptively similar active Florida LLC name exists. If "Nomad Labs LLC" is taken, backup options:
- Nomad Labs Software LLC
- Nomad Labs Holdings LLC
- Nomad Labs FL LLC

---

## Field-by-field data to enter

### Article I — Name of Limited Liability Company

```
Nomad Labs LLC
```

### Article II — Principal Place of Business

Your St. Pete Beach address works as the Principal Place of Business since you're a Florida resident.

```
Street Address: 5353 Gulf Blvd APT A304
City:           St. Pete Beach
State:          FL
Zip Code:       33706
```

**Mailing Address:** (same as Principal)
```
Street Address: 5353 Gulf Blvd APT A304
City:           St. Pete Beach
State:          FL
Zip Code:       33706
```

### Article III — Registered Agent

This is the family member you mentioned who will receive legal mail. Fill in their info:

```
Registered Agent Name:     [FAMILY MEMBER FULL LEGAL NAME]
Street Address:            [THEIR FL STREET ADDRESS]
City:                      [CITY]
State:                     FL
Zip Code:                  [ZIP]
```

**Note:** If you want to use your own address (5353 Gulf Blvd APT A304) and be your own registered agent, you can. Your name and address become public record either way since you're already listed as Principal. This actually simplifies things — one Florida address instead of managing forwarded mail from a family member.

**If you'd rather be your own registered agent:**
```
Registered Agent Name:     Emilio John Alecci
Street Address:            5353 Gulf Blvd APT A304
City:                      St. Pete Beach
State:                     FL
Zip Code:                  33706
```

**Your call.** Both are fine. Being your own registered agent is easier (no dependency on family forwarding mail promptly) and since you're a Florida resident, you qualify. The only downside is you need to physically be at that address during business hours often enough to receive legal mail — which, given your nomadic lifestyle, might be a consideration. A family member avoids that issue.

### Article IV — Management Structure

```
Select: Member-Managed
```

### Article V — Authorized Member

```
Name:    Emilio John Alecci
Title:   Managing Member (AMBR)
Address: 5353 Gulf Blvd APT A304, St. Pete Beach, FL 33706
```

The title code "AMBR" is Florida's designation for Authorized Member (dropdown on the form).

### Article VI — Effective Date

```
Select: Filing Date (default)
```

### Article VII — Signature

```
Signature: Emilio John Alecci
Date:      [date of filing]
```

---

## After you file

### Immediate (day of filing)
1. Save confirmation email with Document Number (L26000XXXXXX)
2. Download stamped Articles PDF

### Within a week of approval (5-7 business days)

**1. Apply for EIN**
   - https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online
   - Entity type: **Limited Liability Company, 1 member**
   - Tax classification: **Disregarded Entity** (default for single-member — income flows to your Schedule C)
   - Do NOT reuse Kaitie's sole-prop EIN. Different legal entity needs different EIN.
   - 15 minutes, instant issue, free. Download CP575 letter.

**2. Open LLC bank account**
   - **Mercury** recommended (free, fast online onboarding, no minimum)
   - Requires: Articles of Organization, EIN letter, your ID
   - Only use this account for LLC transactions going forward. No commingling.

**3. File BOI with FinCEN**
   - https://boiefiling.fincen.gov/
   - Within **90 days** of LLC approval
   - Free, ~15 minutes, you're the sole beneficial owner
   - Need: legal name, DOB, residential address, ID document (driver's license or passport)
   - Penalty if not filed: up to $591/day
   - (Enforcement has been affected by litigation in 2025 — check fincen.gov status before deadline. When uncertain, file — no penalty for filing.)

**4. Florida Annual Report**
   - Due between Jan 1 and May 1 each year starting the year after formation
   - $138.75 filing fee
   - $400 late fee after May 1

---

## Checklist before filing

- [ ] LLC name "Nomad Labs LLC" confirmed available on sunbiz.org
- [ ] Decided on registered agent: yourself OR family member
  - If family member: their full legal name and FL street address collected
  - If yourself: using 5353 Gulf Blvd APT A304
- [ ] Credit card ready for $125 fee

---

## Timeline

- **Today:** File on sunbiz.org ($125)
- **5-7 business days later:** Florida approves
- **Immediately after approval:** Apply for EIN (15 min, free, instant)
- **Week 1:** Open Mercury business account
- **Within 30 days:** Transfer Revflo and PetPal assets to LLC's EIN
- **Within 90 days:** File BOI with FinCEN

---

## Asset transfer priority order (after EIN in hand)

**Critical path (unblocks Twilio A2P resubmission):**
- **Twilio:** Update account business info to Nomad Labs LLC + new EIN. Resubmit A2P registration. Your previous rejection was about the EIN not matching the sole-prop name — a fresh Nomad Labs LLC EIN should solve this.

**Core infrastructure (week 1):**
- **Stripe:** Contact Stripe support to convert account from individual/sole-prop to Nomad Labs LLC. Provide new EIN, Articles, LLC bank info. Takes 1-2 weeks.
- **Supabase, Vercel, Resend, Anthropic:** Update billing to Nomad Labs LLC with LLC bank card.
- **Domain registrar for revflo.app and PetPal domain:** Update registrant to Nomad Labs LLC.
- **GitHub:** Transfer repos to a Nomad Labs organization, or document LLC ownership via Operating Agreement.
- **Apple Developer Account (for PetPal app):** Update account to Nomad Labs LLC. This may require a DUNS number for the LLC — Apple uses D&B for business verification. Free to get. Apply at dnb.com. Takes ~1-2 weeks. Plan accordingly if you're updating the App Store listing soon.

---

## Common mistakes to avoid

1. **Don't reuse Kaitie's sole-prop EIN.** Different entity, different EIN.
2. **Don't skip BOI filing.** $591/day penalty.
3. **Don't use PO Box** for Principal Place of Business or Registered Agent. Florida rejects these.
4. **Don't mix personal and LLC funds.** Open Mercury immediately, run everything through LLC account.
5. **Apple Developer transfer can be slow.** If PetPal needs updates in the App Store soon, start the DUNS + transfer process early.
