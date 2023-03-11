import { Button, PageTitle } from '@pluralsh/design-system'
import { Div, Flex } from 'honorable'
import { Link, Outlet, useLocation } from 'react-router-dom'

import BillingConsumptionProvider from './BillingConsumptionProvider'
import BillingBankCardProvider from './BillingBankCardProvider'
import BillingLegacyUserBanner from './BillingLegacyUserBanner'

function BillingLayout() {
  const { pathname } = useLocation()

  return (
    <BillingConsumptionProvider>
      <BillingBankCardProvider>
        <PageTitle heading="Billing">
          <Flex>
            <Button
              tertiary
              backgroundColor={pathname.endsWith('billing') ? 'fill-two' : undefined}
              as={Link}
              to="/account/billing"
            >
              Manage plan
            </Button>
            <Button
              tertiary
              backgroundColor={pathname.endsWith('payments') ? 'fill-two' : undefined}
              as={Link}
              to="/account/billing/payments"
            >
              Payments
            </Button>
          </Flex>
        </PageTitle>
        <>
          <BillingLegacyUserBanner withBottomMargin={false} />
          <Div
            flexGrow
            flexShrink={0}
            overflowY="auto"
            paddingRight={1}
          >
            <Outlet />
          </Div>
        </>
      </BillingBankCardProvider>
    </BillingConsumptionProvider>
  )
}

export default BillingLayout
