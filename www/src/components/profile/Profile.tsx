import { useMutation } from '@apollo/client'
import { Box, Stack, ThemeContext } from 'grommet'
import { Div, Flex, P } from 'honorable'
import {
  AppIcon,
  Button,
  Chip,
  ContentCard,
  PageTitle,
  ValidatedInput,
} from '@pluralsh/design-system'
import { useContext, useEffect, useState } from 'react'
import { useFilePicker } from 'react-sage'

import CurrentUserContext from '../../contexts/CurrentUserContext'
import { UPDATE_USER } from '../users/queries'
import {
  DEFAULT_CHART_ICON,
  DarkProviderIcons,
  ProviderIcons,
} from '../constants'

function Attribute({ header, children }: any) {
  return (
    <Box
      gap="small"
      basis="1/2"
    >
      <P fontWeight="bold">{header}</P>
      <Box
        direction="row"
        gap="small"
        align="end"
      >
        {children}
      </Box>
    </Box>
  )
}

export function Profile() {
  const { files, onClick, HiddenFileInput } = useFilePicker({})
  const me = useContext(CurrentUserContext)
  const { dark } = useContext(ThemeContext) as any
  const [name, setName] = useState(me.name)
  const [email, setEmail] = useState(me.email)
  const [avatarConst, setAvatar] = useState(me.avatar)
  const [avatarFile, setAvatarFile] = useState<any>()
  const [mutation, { loading }] = useMutation(UPDATE_USER, {
    variables: { attributes: { name, email, avatar: avatarFile } },
  })

  let url: string | undefined

  if (me.provider) {
    url = ProviderIcons[me.provider] || DEFAULT_CHART_ICON

    if (dark && DarkProviderIcons[me.provider]) {
      url = DarkProviderIcons[me.provider]
    }
  }

  let avatar: string | undefined

  if (avatarConst) {
    avatar = avatarConst
  }

  useEffect(() => {
    if (files && files.length > 0) {
      setAvatar(URL.createObjectURL(files[0]))
      setAvatarFile(files[0])
    }
  }, [files])

  return (
    <Div paddingBottom="large">
      <PageTitle heading="Profile" />
      <ContentCard overflowY={undefined}>
        <Box
          gap="large"
          margin={{ bottom: 'medium' }}
          direction="row"
        >
          <Attribute header="Profile picture">
            <Stack
              anchor="bottom-right"
              style={{ height: '96px', width: '96px' }}
            >
              <AppIcon
                name={name}
                url={avatar}
                spacing="none"
                size="medium"
              />
            </Stack>
            <Box gap="xsmall">
              <Button
                small
                secondary
                onClick={onClick}
              >
                {avatar ? 'Switch' : 'Upload'}
              </Button>
              {!!avatar && (
                <Button
                  small
                  destructive
                  onClick={() => {
                    setAvatar(null)
                    setAvatarFile(null)
                  }}
                >
                  Delete
                </Button>
              )}
            </Box>
            <HiddenFileInput
              accept=".jpg, .jpeg, .png"
              multiple={false}
            />
          </Attribute>
          {me.provider && (
            <Attribute header="Provider">
              <AppIcon
                url={url}
                alt={me.provider}
              />
            </Attribute>
          )}
        </Box>
        <Box gap="small">
          <ValidatedInput
            label="Full name"
            width="100%"
            value={name}
            onChange={({ target: { value } }) => setName(value)}
          />
          <ValidatedInput
            label="Email address"
            width="100%"
            value={email}
            onChange={({ target: { value } }) => setEmail(value)}
            endIcon={
              me.emailConfirmed ? null : (
                <Chip
                  size="small"
                  hue="lighter"
                >
                  Pending verification
                </Chip>
              )
            }
          />
        </Box>
        <Flex
          justifyContent="flex-end"
          marginTop="small"
        >
          <Button
            onClick={() => mutation()}
            loading={loading}
          >
            Save
          </Button>
        </Flex>
      </ContentCard>
    </Div>
  )
}
