import { Flex } from 'honorable'
import { useTheme } from 'styled-components'
import { ReactElement, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { useDevTokenInputSecretCode } from '../hooks/useDevToken'
import { AuthorizationUrl, RootQueryType, ScmProvider } from '../../../generated/graphql'
import useOnboarded from '../hooks/useOnboarded'
import { ResponsiveLayoutSpacer } from '../../utils/layout/ResponsiveLayoutSpacer'
import { ResponsiveLayoutContentContainer } from '../../utils/layout/ResponsiveLayoutContentContainer'
import { ResponsiveLayoutSidenavContainer } from '../../utils/layout/ResponsiveLayoutSidenavContainer'

import OnboardingHeader from './OnboardingHeader'
import OnboardingSidenav from './OnboardingSidenav'
import { OnboardingFlow } from './OnboardingFlow'
import { ContextProps, OnboardingContext } from './context/onboarding'
import { defaultSections, useSection } from './context/hooks'
import {
  CloudProps,
  SCMProps,
  Section,
  SectionKey,
  Sections,
  WorkspaceProps,
} from './context/types'

function Onboarding({ active, children }: Partial<OnboardingProps>) {
  useDevTokenInputSecretCode()

  const theme = useTheme()
  const { section, setSection } = useSection(active)
  const navigate = useNavigate()
  const { fresh: isOnboarding } = useOnboarded()

  return (
    <Flex
      width="100%"
      height="100%"
      direction="column"
      alignItems="center"
      overflowY="auto"
    >
      {isOnboarding && <OnboardingHeader onRestart={() => navigate('/shell')} />}
      <Flex
        position="relative"
        width="100%"
        flexGrow={1}
        overflow="hidden"
        marginTop="xxxlarge"
      >
        <ResponsiveLayoutSpacer />
        <ResponsiveLayoutSidenavContainer
          marginRight={theme.spacing.xlarge - theme.spacing.small}
          marginLeft="xlarge"
          paddingRight="small"
          overflowY="auto"
          flexShrink={0}
        >
          <OnboardingSidenav section={section} />
        </ResponsiveLayoutSidenavContainer>
        <ResponsiveLayoutContentContainer
          overflowY="auto"
          paddingBottom="large"
          paddingHorizontal="xxsmall"
          marginRight="xlarge"
          marginRight-desktop-down={theme.spacing.large}
        >
          {!children && (
            <OnboardingFlow
              onNext={() => setSection(section.next || section)}
              onBack={() => setSection(section.prev || section)}
            />
          )}

          {children && children}
        </ResponsiveLayoutContentContainer>
        <ResponsiveLayoutSpacer />
      </Flex>
    </Flex>
  )
}

interface OnboardingProps {
  accessToken?: string
  provider?: ScmProvider;
  authUrlData?: RootQueryType
  active?: SectionKey
  children?: ReactElement | Array<ReactElement>
}

function OnboardingWithContext({
  accessToken, provider, authUrlData, ...props
}: OnboardingProps): ReactElement {
  const [scm, setSCM] = useState<SCMProps>({
    token: accessToken,
    provider,
    authUrls: authUrlData?.scmAuthorization as Array<AuthorizationUrl>,
  })
  const [valid, setValid] = useState<boolean>(true)
  const [cloud, setCloud] = useState<CloudProps>({} as CloudProps)
  const [sections, setSections] = useState<Sections>(defaultSections())
  const [section, setSection] = useState<Section>(sections[SectionKey.CREATE_REPOSITORY]!)
  const [workspace, setWorkspace] = useState<WorkspaceProps>({} as WorkspaceProps)

  const context = useMemo<ContextProps>(() => ({
    scm,
    setSCM,
    cloud,
    setCloud,
    valid,
    setValid,
    sections,
    setSections,
    section,
    setSection,
    workspace,
    setWorkspace,
  }), [scm, cloud, valid, sections, section, workspace])

  return (
    <OnboardingContext.Provider value={context}>
      <Onboarding {...props} />
    </OnboardingContext.Provider>
  )
}

export { OnboardingWithContext as Onboarding }
