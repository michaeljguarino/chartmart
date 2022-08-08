import { Avatar, Flex, Text } from 'honorable'
import { Tab } from 'pluralsh-design-system'
import { Link, Outlet, useLocation } from 'react-router-dom'

import { Box } from 'grommet'

import { useContext } from 'react'

import { ResponsiveLayoutContentContainer, ResponsiveLayoutSidenavContainer, ResponsiveLayoutSpacer } from '../layout/ResponsiveLayout'
import { CurrentUserContext } from '../login/CurrentUser'

const DIRECTORY = [
  { path: '/profile/me', label: 'Profile' },
  { path: '/profile/security', label: 'Security' },
  { path: '/profile/tokens', label: 'Access tokens' },
  { path: '/profile/keys', label: 'Public keys' },
  { path: '/profile/eab', label: 'EAB credentials' },
]

export function MyProfile() {
  const me = useContext(CurrentUserContext)
  const { pathname } = useLocation()

  return (
    <Flex
      height="100%"
      width="100%"
      overflowY="hidden"
      padding={32}
      paddingTop={88}
    >
      <ResponsiveLayoutSidenavContainer width={240}>
        <Box
          direction="row"
          gap="small"
          margin={{ bottom: '32px' }}
        >
          <Avatar
            name={me.name}
            src={me.avatar}
            size={64}
            fontSize="12px"
          />
          <Box>
            <Text subtitle2>{me.name}</Text>
            {me?.roles?.admin && (
              <Text
                caption
                color="text-xlight"
              >
                Admin at Plural
              </Text>
            )}
          </Box>
        </Box>
        {DIRECTORY.map(({ label, path }, i) => (
          <Link
            key={i}
            to={path}
            style={{ textDecoration: 'none' }}
          >
            <Tab
              active={pathname === path}
              vertical
              textDecoration="none"
            >{label}
            </Tab>
          </Link>
        ))}
      </ResponsiveLayoutSidenavContainer>
      <ResponsiveLayoutSpacer />
      <ResponsiveLayoutContentContainer><Outlet /></ResponsiveLayoutContentContainer>
      <ResponsiveLayoutSpacer />
    </Flex>
  )
}
