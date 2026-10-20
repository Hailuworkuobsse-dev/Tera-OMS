import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { MorningMapPage } from '../modules/morning-map';
import { RouteBuilderPage } from '../modules/route-builder';
import { DispatchBoardPage } from '../modules/dispatch-board';
import { CreditStopListPage } from '../modules/credit-stop-list';

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <Navigate to="/routes" replace /> },
      { path: 'routes',  element: <MorningMapPage /> },
      { path: 'builder', element: <RouteBuilderPage /> },
      { path: 'board',   element: <DispatchBoardPage /> },
      { path: 'credit',  element: <CreditStopListPage /> },
    ],
  },
]);

export function AppRouter() { return <RouterProvider router={router} />; }
