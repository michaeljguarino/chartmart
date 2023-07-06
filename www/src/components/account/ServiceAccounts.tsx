import { useQuery } from '@apollo/client'
import { Div, Flex } from 'honorable'
import isEmpty from 'lodash/isEmpty'
import { EmptyState, PageTitle, SearchIcon } from '@pluralsh/design-system'
import { useCallback, useContext, useEffect, useState } from 'react'

import { Placeholder } from '../utils/Placeholder'
import ListInput from '../utils/ListInput'
import { List, ListItem } from '../utils/List'
import {
  extendConnection,
  removeConnection,
  updateCache,
} from '../../utils/graphql'
import { StandardScroller } from '../utils/SmoothScroller'
import LoadingIndicator from '../utils/LoadingIndicator'

import SubscriptionContext from '../../contexts/SubscriptionContext'

import BillingTrialBanner from './billing/BillingTrialBanner'

import { USERS_Q } from './queries'
import { CreateServiceAccount } from './CreateServiceAccount'
import { ServiceAccount } from './User'
import BillingLegacyUserBanner from './billing/BillingLegacyUserBanner'
import BillingFeatureBlockBanner from './billing/BillingFeatureBlockBanner'

function Header({ q, setQ }: any) {
  return (
    <ListInput
      width="100%"
      value={q}
      placeholder="Search a user"
      startIcon={<SearchIcon color="text-light" />}
      onChange={({ target: { value } }) => setQ(value)}
      flexGrow={0}
    />
  )
}

function ServiceAccountsInner({ q, data, loading, fetchMore }: any) {
  const [listRef, setListRef] = useState<any>(null)
  const update = useCallback(
    (cache, { data: { deleteUser } }) =>
      updateCache(cache, {
        query: USERS_Q,
        variables: { q, serviceAccount: true },
        update: (prev) => removeConnection(prev, deleteUser, 'users'),
      }),
    [q]
  )

  const [dataCache, setDataCache] = useState(data)

  useEffect(() => {
    if (data) {
      setDataCache(data)
    }
  }, [data])

  if (!data && !dataCache) return <LoadingIndicator />

  const { edges, pageInfo } = data?.users || dataCache?.users || {}

  return (
    <Div
      flexGrow={1}
      width="100%"
    >
      {edges?.length > 0 ? (
        <StandardScroller
          listRef={listRef}
          setListRef={setListRef}
          items={edges}
          mapper={({ node: user }, { prev, next }) => (
            <ListItem
              key={user.id}
              first={!prev.node}
              last={!next.node}
            >
              <ServiceAccount
                user={user}
                update={update}
              />
            </ListItem>
          )}
          loadNextPage={() =>
            pageInfo.hasNextPage &&
            fetchMore({
              variables: { cursor: pageInfo.endCursor },
              updateQuery: (prev, { fetchMoreResult: { users } }) =>
                extendConnection(prev, users, 'users'),
            })
          }
          hasNextPage={pageInfo.hasNextPage}
          loading={loading}
          placeholder={Placeholder}
        />
      ) : (
        <EmptyState
          message={
            isEmpty(q)
              ? "Looks like you don't have any service accounts yet."
              : "Looks like you don't have any service accounts matching search criteria."
          }
        >
          <CreateServiceAccount q={q} />
        </EmptyState>
      )}
    </Div>
  )
}

export function ServiceAccounts() {
  const [q, setQ] = useState('')
  const { data, loading, fetchMore } = useQuery(USERS_Q, {
    variables: { q, serviceAccount: true },
    fetchPolicy: 'cache-and-network',
  })
  const { availableFeatures } = useContext(SubscriptionContext)
  const isAvailable =
    !!availableFeatures?.userManagement || !isEmpty(data?.users?.edges)

  return (
    <Flex
      flexGrow={1}
      flexDirection="column"
      maxHeight="100%"
    >
      <PageTitle heading="Service accounts">
        <CreateServiceAccount q={q} />
      </PageTitle>
      <BillingLegacyUserBanner feature="service accounts" />
      <BillingTrialBanner />
      {isAvailable ? (
        <List>
          <Header
            q={q}
            setQ={setQ}
          />
          <ServiceAccountsInner
            q={q}
            data={data}
            loading={loading}
            fetchMore={fetchMore}
          />
        </List>
      ) : (
        <BillingFeatureBlockBanner
          feature="service acccounts"
          description="Create assumable identities that enable multiple people to manage Plural installations."
          placeholderImageURL="/placeholders/service-accounts.png"
        />
      )}
    </Flex>
  )
}
