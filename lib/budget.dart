/// Recommended monthly budget, split into everyday categories.
///
/// The starting shares are loosely based on how the average U.S. household
/// spends its money (BLS Consumer Expenditure Survey) blended with the common
/// "needs / wants / savings" guideline. Categories that grow with each person
/// (groceries, toiletries, clothing...) get more weight for bigger households;
/// everything is then rescaled so the lines always add up to the income.
library;

enum BudgetGroup {
  needs('Needs', 'Bills and necessities'),
  wants('Wants', 'Nice to have, easy to trim'),
  savings('Savings & debt', 'Paying your future self');

  const BudgetGroup(this.label, this.blurb);
  final String label;
  final String blurb;
}

class BudgetCategory {
  const BudgetCategory(
    this.group,
    this.name,
    this.examples,
    this.basePercent, {
    this.perPerson = false,
  });

  final BudgetGroup group;
  final String name;

  /// What typically goes in it, shown under the name.
  final String examples;

  /// Share of take-home pay for a one-person household.
  final double basePercent;

  /// Grows with household size.
  final bool perPerson;

  /// Stable key for saved data, e.g. "toiletries-personal-care".
  String get id => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

const budgetCategories = [
  BudgetCategory(
    BudgetGroup.needs,
    'Housing',
    'Rent or mortgage, renters / home insurance',
    27,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Utilities',
    'Electricity, water, gas, trash',
    6,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Phone & internet',
    'Cell phone plan, home internet',
    3,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Groceries',
    'Food and drinks to cook at home',
    9,
    perPerson: true,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Transportation',
    'Car payment, gas, car insurance, upkeep, transit',
    11,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Health care',
    'Insurance premiums, copays, prescriptions',
    6,
    perPerson: true,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Toiletries & personal care',
    'Toothpaste, soap, shampoo, deodorant, haircuts',
    1.5,
    perPerson: true,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Household supplies',
    'Toilet paper, paper towels, cleaning supplies, laundry detergent',
    1.5,
    perPerson: true,
  ),
  BudgetCategory(
    BudgetGroup.needs,
    'Clothing',
    'Clothes, shoes, seasonal items',
    2.5,
    perPerson: true,
  ),
  BudgetCategory(
    BudgetGroup.wants,
    'Dining out',
    'Restaurants, takeout, coffee',
    4,
  ),
  BudgetCategory(
    BudgetGroup.wants,
    'Entertainment',
    'Streaming, hobbies, outings',
    4,
  ),
  BudgetCategory(
    BudgetGroup.wants,
    'Gifts & donations',
    'Birthdays, holidays, charity',
    2,
  ),
  BudgetCategory(
    BudgetGroup.wants,
    'Miscellaneous',
    'Small unexpected costs',
    3.5,
  ),
  BudgetCategory(
    BudgetGroup.savings,
    'Emergency fund & savings',
    'Aim for 3–6 months of expenses',
    12,
  ),
  BudgetCategory(
    BudgetGroup.savings,
    'Retirement & extra debt payments',
    '401(k) / IRA, paying down cards or loans',
    7,
  ),
];

class BudgetLine {
  const BudgetLine(this.category, this.percent, this.amount);
  final BudgetCategory category;

  /// Share of income, 0–100.
  final double percent;

  /// Monthly amount.
  final double amount;
}

/// Largest household size the budget accepts.
const maxHousehold = 50;

/// Extra weight per additional person for [BudgetCategory.perPerson] lines.
const _perPersonGrowth = 0.3;

/// Splits [income] (monthly) across [budgetCategories] for a household of
/// [people]. The lines always add up to [income].
List<BudgetLine> recommendedBudget(double income, int people) {
  final n = people.clamp(1, maxHousehold);
  final weights = [
    for (final c in budgetCategories)
      c.basePercent * (c.perPerson ? 1 + _perPersonGrowth * (n - 1) : 1),
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  return [
    for (var i = 0; i < budgetCategories.length; i++)
      BudgetLine(
        budgetCategories[i],
        weights[i] / total * 100,
        income * weights[i] / total,
      ),
  ];
}
