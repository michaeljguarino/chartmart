import { Div, Flex } from 'honorable'
import { Tab } from 'pluralsh-design-system'
import { Link, Outlet, useLocation } from 'react-router-dom'

import { SidebarTabs } from '../utils/SidebarTabs'

const DIRECTORY = [
  { path: '/profile/me', label: 'Profile' },
  { path: '/profile/security', label: 'Security' },
  { path: '/profile/tokens', label: 'Access tokens' },
  { path: '/profile/keys', label: 'Public keys' },
  { path: '/profile/eab', label: 'EAB credentials' },
]

export function MyProfile() {
  const { pathname } = useLocation()

  return (
    <Flex
      height="100%"
      width="100%"
      overflowY="hidden"
    >
      <SidebarTabs>
        {DIRECTORY.map(({ label, path }) => (
          <Link
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
      </SidebarTabs>
      <Div
        flexGrow={1}
        pt={1.5}
        pr={1.5}
        height="100%"
        maxHeight="100%"
        overflowY="auto"
      >
        <Outlet />
      </Div>
    </Flex>
  )
}
