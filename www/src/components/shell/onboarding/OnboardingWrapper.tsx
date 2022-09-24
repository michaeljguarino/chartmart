import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react'
import { Flex } from 'honorable'

import {
  ResponsiveLayoutContentContainer,
  ResponsiveLayoutSidecarContainer,
  ResponsiveLayoutSidenavContainer,
  ResponsiveLayoutSpacer,
} from '../../layout/ResponsiveLayout'

import SelectedApplicationsContext, { SelectedApplicationsContextType } from '../../../contexts/SelectedApplicationsContext'

import { persistApplications, retrieveApplications } from '../persistance'

import OnboardingSidenav from './OnboardingSidenav'
import OnboardingSidecar from './OnboardingSidecar'
import OnboardingTitle from './OnboardingTitle'

import SplashToLogoTransition from './SplashToLogoTransition'

function OnboardingWrapper({
  showSplashScreen = false,
  stepIndex = 0,
  childIsReady = true,
  cliMode = false,
  onRestart = () => {},
  children,
}) {
  const [selectedApplications, setSelectedApplications] = useState<any[]>(retrieveApplications())
  const selectedApplicationsContextValue = useMemo<SelectedApplicationsContextType>(() => ({ selectedApplications, setSelectedApplications }), [selectedApplications])

  const handleRestart = useCallback(() => {
    setSelectedApplications([])
    onRestart()
  }, [onRestart])

  useEffect(() => {
    persistApplications(selectedApplications)
  }, [selectedApplications])

  return (
    <SelectedApplicationsContext.Provider value={selectedApplicationsContextValue}>
      <Flex
        width="100%"
        height="100%"
        direction="column"
        alignItems="center"
        paddingTop="xxlarge"
        overflowY="auto"
      >
        <SplashToLogoTransition
          showSplashScreen={showSplashScreen}
          splashTimeout={1200}
          childIsReady={childIsReady}
        >
          {childIsReady && (
            <Flex
              position="relative"
              width="100%"
              flexGrow={1}
              overflow="hidden"
            >
              <ResponsiveLayoutSpacer />
              <ResponsiveLayoutSidenavContainer
                marginTop={82}
                marginRight={30}
                paddingRight="xxsmall"
                overflowY="auto"
              >
                <OnboardingSidenav
                  stepIndex={stepIndex}
                  cliMode={cliMode}
                  onRestart={handleRestart}
                />
              </ResponsiveLayoutSidenavContainer>
              <ResponsiveLayoutContentContainer
                overflowY="auto"
                paddingBottom="large"
                paddingHorizontal="xxsmall"
                marginRight-desktop-down={30}
              >
                <OnboardingTitle />
                {children}
              </ResponsiveLayoutContentContainer>
              <ResponsiveLayoutSidecarContainer
                marginLeft={30}
                marginTop={57}
                marginRight="xlarge"
                overflowY="auto"
              >
                <OnboardingSidecar areApplicationsDisplayed={stepIndex > 0} />
              </ResponsiveLayoutSidecarContainer>
              <ResponsiveLayoutSpacer />
            </Flex>
          )}
        </SplashToLogoTransition>
      </Flex>
    </SelectedApplicationsContext.Provider>
  )
}

export default OnboardingWrapper
