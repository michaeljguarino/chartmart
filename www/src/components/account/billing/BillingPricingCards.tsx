import { Flex } from 'honorable'
import { Button } from '@pluralsh/design-system'

import BillingPricingCard from './BillingPricingCard'

function BillingPricingCards() {
  return (
    <Flex gap="medium">
      <BillingPricingCard
        selected
        title="Open-source"
        subtitle={(
          <>
            Free
            <br />
            <br />
          </>
        )}
        items={[
          {
            label: 'Free forever',
            checked: true,
          },
          {
            label: 'Unlimited apps',
            checked: true,
          },
          {
            label: 'Unlimited users',
            checked: true,
          },
          {
            label: 'Enforced SSO',
            checked: true,
          },
          {
            label: 'Acces to community',
            checked: true,
          },
        ]}
        callToAction={(
          <Button
            primary
            disabled
            width="100%"
          >
            Current plan
          </Button>
        )}
      />
      <BillingPricingCard
        title="Professional"
        subtitle={(
          <>
            $399/cluster/month
            <br />
            $49/user/month
          </>
        )}
        items={[
          {
            label: 'Open-source perks',
            checked: false,
          },
          {
            label: 'User management',
            checked: true,
          },
          {
            label: 'VPN',
            checked: true,
          },
          {
            label: '24 hours SLA\'s',
            checked: true,
          },
          {
            label: 'Emergency hotfixes',
            checked: true,
          },
        ]}
        callToAction={(
          <Button
            primary
            width="100%"
          >
            Upgrade now
          </Button>
        )}
      />
      <BillingPricingCard
        title="Enterprise"
        subtitle={(
          <>
            Custom
            <br />
            <br />
          </>
        )}
        items={[
          {
            label: 'Professional perks',
            checked: false,
          },
          {
            label: 'Audit logs',
            checked: true,
          },
          {
            label: 'Dedicated enf support',
            checked: true,
          },
          {
            label: '4 hours SLA\'s',
            checked: true,
          },
          {
            label: 'Commercial license',
            checked: true,
          },
        ]}
        callToAction={(
          <Button
            secondary
            width="100%"
          >
            Contact sales
          </Button>
        )}
      />
    </Flex>
  )
}

export default BillingPricingCards
