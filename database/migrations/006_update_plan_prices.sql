-- Assign prices to default seeded plans (in INR)
UPDATE subscription_plans SET price = 0.00 WHERE slug = 'starter';
UPDATE subscription_plans SET price = 499.00 WHERE slug = 'growth';
UPDATE subscription_plans SET price = 999.00 WHERE slug = 'business';
UPDATE subscription_plans SET price = 1999.00 WHERE slug = 'enterprise';
