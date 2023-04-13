import { useMutation, useQuery } from '@apollo/client'
import { Box } from 'grommet'
import { Span, Text } from 'honorable'
import moment from 'moment'
import { useState } from 'react'

import { InfoIcon, PageTitle, Tooltip } from '@pluralsh/design-system'

import isEmpty from 'lodash/isEmpty'

import { Placeholder } from '../utils/Placeholder'

import { extendConnection } from '../../utils/graphql'
import { Confirm } from '../utils/Confirm'

import { DELETE_KEY, LIST_KEYS } from '../users/queries'
import { StandardScroller } from '../utils/SmoothScroller'

import { DeleteIconButton } from '../utils/IconButtons'

import LoadingIndicator from '../utils/LoadingIndicator'

import { ListItem } from './ListItem'

const TOOLTIP = 'Public keys are used to share access to an encrypted repository.'

function PublicKey({ pubkey: key, first, last }: any) {
  const [confirm, setConfirm] = useState(false)
  const [mutation, { loading, error }] = useMutation(DELETE_KEY, {
    variables: { id: key.id },
    refetchQueries: [{ query: LIST_KEYS }],
    onCompleted: () => setConfirm(false),
  })

  return (
    <>
      <ListItem
        first={first}
        last={last}
      >
        <Box
          flex="grow"
          gap="xsmall"
        >
          <Box
            direction="row"
            align="center"
            gap="small"
          >
            <Span
              body1
              fontWeight="600"
            >
              {key.name}
            </Span>
          </Box>
          <Span color="text-light">{key.digest.toLowerCase()}</Span>
        </Box>
        <Box
          flex={false}
          direction="row"
          align="center"
          gap="small"
        >
          <Text
            color="text-xlight"
            caption
            style={{ whiteSpace: 'nowrap' }}
          >
            added on {moment(key.insertedAt).format('lll')}
          </Text>
          <DeleteIconButton onClick={() => setConfirm(true)} />
        </Box>
      </ListItem>
      <Confirm
        open={confirm}
        title="Delete Public Key"
        text="Are you sure you want to delete this public key?"
        close={() => setConfirm(false)}
        submit={() => mutation()}
        loading={loading}
        destructive
        error={error}
      />
    </>
  )
}

export function PublicKeys() {
  const [listRef, setListRef] = useState<any>(null)
  const { data, loading, fetchMore } = useQuery(LIST_KEYS)

  if (!data) return <LoadingIndicator />

  const { edges, pageInfo } = data.publicKeys

  return (
    <Box fill>
      <PageTitle
        heading="Public keys"
        justifyContent="flex-start"
      >
        <Tooltip
          width="315px"
          label={TOOLTIP}
        >
          <Box
            flex={false}
            pad="6px"
            round="xxsmall"
            hoverIndicator="fill-two"
          >
            <InfoIcon />
          </Box>
        </Tooltip>
      </PageTitle>
      <Box fill>
        {edges?.length
          ? (
            <StandardScroller
              listRef={listRef}
              setListRef={setListRef}
              items={edges}
              placeholder={Placeholder}
              mapper={({ node }, { prev, next }) => (
                <PublicKey
                  key={node.id}
                  pubkey={node}
                  first={isEmpty(prev.node)}
                  last={isEmpty(next.node)}
                />
              )}
              loading={loading}
              hasNextPage={pageInfo.hasNextPage}
              loadNextPage={pageInfo.hasNextPage && fetchMore({
                variables: { cursor: pageInfo.endCursor },
                updateQuery: (prev, { fetchMoreResult: { publicKeys } }) => extendConnection(prev, publicKeys, 'publicKeys'),
              })}
            />
          ) : (<Span>You do not have any public keys yet.</Span>)}
      </Box>
    </Box>
  )
}
