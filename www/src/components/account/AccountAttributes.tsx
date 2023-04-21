import {
  Div,
  Flex,
  Form,
  Span,
} from 'honorable'
import {
  Button,
  Chip,
  ContentCard,
  FormField,
  Input,
  PageTitle,
  ValidatedInput,
} from '@pluralsh/design-system'
import { useContext, useMemo, useState } from 'react'
import { ThemeContext } from 'styled-components'

import { useUpdateState } from '../../hooks/useUpdateState'
import CurrentUserContext from '../../contexts/CurrentUserContext'
import { notNil, notNilAnd } from '../../utils/ts-notNil'
import SaveButton from '../utils/SaveButton'
import { GqlError } from '../utils/Alert'
import { DeleteIconButton } from '../utils/IconButtons'
import { List, ListItem } from '../utils/List'
import { Account, DomainMapping, useUpdateAccountMutation } from '../../generated/graphql'
import { removeTypename } from '../../utils/removeTypename'

import { Confirm } from '../utils/Confirm'

type DomainMappingFuncProps = {
  mapping: DomainMapping
  remove: () => void
  first: boolean
  last: boolean
}

function DomainMappingFunc({
  mapping,
  remove,
  first,
  last,
}: DomainMappingFuncProps) {
  const theme = useContext(ThemeContext)
  const [confirm, setConfirm] = useState(false)

  return (
    <>
      <ListItem
        first={first}
        last={last}
      >
        <Flex
          gap={theme.spacing.medium}
          alignItems="center"
        >
          <Div
            fill="horizontal"
            flexGrow={1}
          >
            <Span fontWeight="bold">{mapping.domain}</Span>
          </Div>
          <Flex
            flexDirection="row"
            alignItems="center"
            gap="small"
          >
            {mapping.enableSso && (
              <Chip
                severity="neutral"
                backgroundColor="fill-three"
                borderColor="border-input"
              >
                SSO
              </Chip>
            )}
            <DeleteIconButton
              onClick={() => {
                setConfirm(true)
              }}
              // @ts-expect-error
              hue="lighter"
            />
          </Flex>
        </Flex>
      </ListItem>
      <Confirm
        title="Confirm deletion"
        text="Are you sure you want to delete this domain? This action is irreversible."
        label="Delete"
        open={confirm}
        close={() => {
          setConfirm(false)
        }}
        submit={() => {
          setConfirm(false)
          remove()
        }}
        destructive
      />
    </>
  )
}

function toFormState(account: Pick<Account, 'name' | 'domainMappings'>) {
  return {
    name: `${account?.name || ''}`,
    domainMappings: account?.domainMappings || [],
  }
}

export function AccountAttributes() {
  const { account } = useContext(CurrentUserContext)

  const {
    state: formState,
    hasUpdates,
    update: updateFormState,
  } = useUpdateState(toFormState(account))

  const [domain, setDomain] = useState('')

  const sortedDomainMappings = useMemo(() => (formState.domainMappings || [])
    .filter(notNil)
    .sort((m1, m2) => `${m1?.domain} || ''`
      .toLowerCase()
      .localeCompare(`${m2?.domain} || ''`.toLowerCase())),
  [formState.domainMappings])

  const [mutation, { loading, error }] = useUpdateAccountMutation({
    variables: {
      attributes: {
        name: formState.name,
        domainMappings: formState.domainMappings,
      },
    },
    update: (_cache, { data }) => {
      if (data?.updateAccount) updateFormState(toFormState(data.updateAccount))
    },
  })

  const addDomain = (d: string) => {
    const newDomains = [
      { domain: d },
      ...(account?.domainMappings?.map(removeTypename) || []),
    ]

    mutation({ variables: { attributes: { domainMappings: newDomains } } })
  }

  const rmDomain = (d?: string) => {
    const newDomains = (account?.domainMappings || [])
      .filter(notNilAnd(mapping => mapping?.domain !== d))
      .map(removeTypename)

    mutation({ variables: { attributes: { domainMappings: newDomains } } })
  }

  function handleAddDomain() {
    if (!domain) return
    addDomain(domain)
    setDomain('')
  }

  return (
    <Form
      onSubmit={event => {
        event.preventDefault()
        if (hasUpdates) {
          mutation()
        }
      }}
      display="flex"
      flexDirection="column"
      paddingBottom="large"
    >
      <PageTitle heading="Account attributes">
        <SaveButton
          dirty={hasUpdates}
          loading={loading}
          error={!!error}
        />
      </PageTitle>
      <ContentCard overflowY={undefined}>
        <Flex
          flexDirection="column"
          gap="large"
        >
          {error && (
            <GqlError
              error={error}
              header="Something went wrong"
            />
          )}
          <ValidatedInput
            label="Account name"
            value={formState.name}
            onChange={({ target: { value } }) => updateFormState({ name: value })}
          />
          <FormField
            label="Domain mappings"
            hint="Register email domains to automatically add users to your
                      account"
          >
            <Flex gap="medium">
              <Div flexGrow={1}>
                <Input
                  value={domain}
                  width="100%"
                  placeholder="enter an email domain"
                  onKeyDown={event => {
                    if (event.key === 'Enter') {
                      event.preventDefault()
                      handleAddDomain()
                    }
                  }}
                  onChange={({ target: { value } }) => setDomain(value)}
                />
              </Div>
              <Div>
                <Button
                  secondary
                  type="button"
                  disabled={!domain}
                  onClick={() => {
                    handleAddDomain()
                  }}
                >
                  Add
                </Button>
              </Div>
            </Flex>
          </FormField>
          {sortedDomainMappings.length > 0 && (
            <List hue="lighter">
              {sortedDomainMappings.map((mapping, i) => (
                <DomainMappingFunc
                  key={mapping?.domain}
                  mapping={mapping}
                  first={i === 0}
                  last={i === sortedDomainMappings.length - 1}
                  remove={() => rmDomain(mapping?.domain)}
                />
              ))}
            </List>
          )}
        </Flex>
      </ContentCard>
    </Form>
  )
}
