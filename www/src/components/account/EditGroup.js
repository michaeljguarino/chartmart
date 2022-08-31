import { useApolloClient, useMutation } from '@apollo/client'
import {
  ComboBox,
  FormField,
  Switch,
  Tab,
  TabList,
  TabPanel,
  ValidatedInput,
} from 'pluralsh-design-system'
import { useRef, useState } from 'react'
import { Flex } from 'honorable'

import { appendConnection, updateCache } from '../../utils/graphql'
import {
  CREATE_GROUP_MEMBERS,
  GROUP_MEMBERS,
  UPDATE_GROUP,
} from '../accounts/queries'
import { GqlError } from '../utils/Alert'

import { Actions } from './Actions'
import { fetchUsers } from './Typeaheads'
import { GroupMembers } from './Group'

const TABS = {
  Attributes: { label: 'Attributes' },
  Users: { label: 'Users' },
}

export function EditGroup({ group, cancel }) {
  const client = useApolloClient()
  const [value, setValue] = useState('')
  const [name, setName] = useState(group.name)
  const [description, setDescription] = useState(group.description)
  const [global, setGlobal] = useState(group.global)
  const [mutation, { loading, error }] = useMutation(UPDATE_GROUP, {
    variables: { id: group.id, attributes: { name, description, global } },
    onCompleted: () => cancel(),
  })
  const [addMut] = useMutation(CREATE_GROUP_MEMBERS, {
    variables: { groupId: group.id },
    update: (cache, { data: { createGroupMember } }) => updateCache(cache, {
      query: GROUP_MEMBERS,
      variables: { id: group.id },
      update: prev => appendConnection(prev, createGroupMember, 'groupMembers'),
    }),
  })
  const [suggestions, setSuggestions] = useState([])
  const tabStateRef = useRef()
  const [view, setView] = useState('Attributes')

  return (
    <Flex
      flexDirection="column"
      gap="large"
    >
      {error && (
        <GqlError
          header="Something went wrong"
          error={error}
        />
      )}
      <TabList
        stateRef={tabStateRef}
        stateProps={{
          orientation: 'horizontal',
          selectedKey: view,
          onSelectionChange: key => setView(key),
        }}
      >
        {Object.entries(TABS).map(([key, { label }]) => (
          <Tab key={key}>{label}</Tab>
        ))}
      </TabList>
      <TabPanel stateRef={tabStateRef}>
        {view === 'Attributes' && (
          <Flex
            flexDirection="column"
            gap="large"
          >
            <ValidatedInput
              label="Name"
              value={name}
              onChange={({ target: { value } }) => setName(value)}
            />
            <ValidatedInput
              label="Description"
              value={description}
              onChange={({ target: { value } }) => setDescription(value)}
            />
            <Switch
              checked={global}
              onChange={({ target: { checked } }) => setGlobal(checked)}
            >
              Apply globally
            </Switch>
          </Flex>
        )}
        {view === 'Users' && (
          <Flex
            flexDirection="column"
            gap="large"
          >
            <FormField
              label="Add users"
              width="100%"
              {...{
                '& :last-child': {
                  marginTop: 0,
                },
              }}
            >
              <ComboBox
                inputValue={value}
                placeholder="Search a user"
                onSelectionChange={key => {
                  setValue('')
                  addMut({ variables: { userId: key } })
                }}
                onInputChange={value => {
                  setValue(value)
                  fetchUsers(client, value, setSuggestions)
                }}
              >
                {suggestions.map(({ label }) => label)}
              </ComboBox>
            </FormField>
            <GroupMembers
              group={group}
              edit
            />

          </Flex>
        )}
      </TabPanel>
      <Actions
        cancel={cancel}
        submit={mutation}
        loading={loading}
        action="Update"
      />
    </Flex>
  )
}
