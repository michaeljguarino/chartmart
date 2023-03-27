import { ReactNode, useContext, useMemo } from 'react'
import moment from 'moment'
import { ApolloError } from '@apollo/client'

import SubscriptionContext, { SubscriptionContextType } from '../../../contexts/SubscriptionContext'

import { PaymentMethodFragment, SubscriptionAccountFragment } from '../../../generated/graphql'

import BillingError from './BillingError'

type BillingSubscriptionProviderPropsType = {
  data?: any
  error?: ApolloError
  refetch: () => void
  children: ReactNode
}

function useExtractPaymentMethods(methodsConnection:
  | SubscriptionAccountFragment['paymentMethods']
  | null
  | undefined) {
  const { paymentMethods, defaultPaymentMethod } = useMemo(() => {
    const result = (methodsConnection?.edges || [])?.reduce((prev, edge) => {
      const curNode = edge?.node

      return {
        defaultPaymentMethod: curNode?.isDefault
          ? curNode
          : prev.defaultPaymentMethod,
        paymentMethods: [
          ...prev.paymentMethods,
          ...(curNode ? [curNode] : []),
        ],
      }
    },
    { paymentMethods: [], defaultPaymentMethod: undefined } as {
      paymentMethods: PaymentMethodFragment[]
      defaultPaymentMethod: PaymentMethodFragment | undefined
    })

    return {
      paymentMethods: result.paymentMethods,
      defaultPaymentMethod: result.defaultPaymentMethod,
    }
  }, [methodsConnection])

  return {
    paymentMethods,
    defaultPaymentMethod,
  }
}

function BillingSubscriptionProvider({
  data, error, refetch, children,
}: BillingSubscriptionProviderPropsType) {
  const { paymentMethods, defaultPaymentMethod } = useExtractPaymentMethods(data?.account?.paymentMethods)

  const subscriptionContextValue = useMemo<SubscriptionContextType>(() => {
    const account = data?.account
    const availableFeatures = account?.availableFeatures
    const billingAddress = account?.billingAddress
    const billingCustomerId = account?.billingCustomerId
    const subscription = account?.subscription
    const plan = subscription?.plan
    const isProPlan = plan?.name === 'Pro'
    const isEnterprisePlan = plan?.name === 'Enterprise'
    const isPaidPlan = isProPlan || isEnterprisePlan
    const isGrandfathered = moment().isBefore(moment(account?.grandfatheredUntil))

    return {
      subscription,
      billingAddress,
      billingCustomerId,
      isProPlan,
      isEnterprisePlan,
      isPaidPlan,
      isGrandfathered,
      account,
      availableFeatures,
      paymentMethods,
      defaultPaymentMethod,
      refetch,
    }
  }, [data?.account, defaultPaymentMethod, paymentMethods, refetch])

  // Query could error if not allowed to fetch paymentMethods, but still return
  // the rest of the account data, so don't show error unless no data was received.
  if (error && !data) {
    return <BillingError>{`${error.name}: ${error.message}`}</BillingError>
  }

  return (
    <SubscriptionContext.Provider value={subscriptionContextValue}>
      {children}
    </SubscriptionContext.Provider>
  )
}

export function useBillingSubscription() {
  const ctx = useContext(SubscriptionContext)

  if (!ctx) {
    throw Error('useBillingSubscription() must be used inside of a <BillingSubscriptionProvider>')
  }

  return ctx
}

export default BillingSubscriptionProvider
